import logging
import os
import httpx
import json
from pathlib import Path

import pandas as pd
import yaml

AUTH_URL = "https://infra.mail.ru:35357/v3"
NOVA_ENDPOINT = "https://infra.mail.ru:8774/v2.1"

# Конфиг — из EDR_CONFIG_DIR (в контейнере read-only каталог из SOPS); выгрузки —
# в EDR_DATA_DIR. По умолчанию текущий каталог (ручной прогон с ноутбука).
CONFIG_DIR = Path(os.environ.get("EDR_CONFIG_DIR", "."))
DATA_DIR = Path(os.environ.get("EDR_DATA_DIR", "."))

# Managed-ресурсы (ноды managed БД, managed kubernetes и т.п.) попадают в список
# Nova как обычные ВМ, но поставить на них агент EDR нельзя — в покрытии они
# только занижают процент. VK Cloud помечает их метаданными, по ним и отличаем.
#
# Ключи, само наличие которых означает managed-ресурс (ключ -> тип):
MANAGED_METADATA_KEYS = {
    "datastore": "database",         # managed БД: datastore/datastore_version
    "mcs_cluster_id": "kubernetes",  # ноды managed kubernetes (MKS)
    "k8s_cluster_id": "kubernetes",
}
# Пары ключ+значение (наличия ключа мало):
MANAGED_METADATA_VALUES = {"sid": {"trove": "database"}}
#
# ВАЖНО: service_user_id для этого НЕ годится — он стоит у обычных ВМ (46 из 71
# в проекте project-a), фильтр по нему выкосил бы треть инфраструктуры.


def managed_kind(metadata: dict) -> str:
    """Тип managed-сервиса по метаданным ВМ; пустая строка — обычная ВМ."""
    metadata = metadata or {}
    for key, kind in MANAGED_METADATA_KEYS.items():
        if key in metadata:
            return kind
    for key, values in MANAGED_METADATA_VALUES.items():
        kind = values.get(str(metadata.get(key, "")).lower())
        if kind:
            return kind
    return ""

logger = logging.getLogger(__name__)

VKC_USERNAME = os.environ.get("VKC_USERNAME")
VKC_PASSWORD = os.environ.get("VKC_PASSWORD")
VKC_PROJECT_ID = os.environ.get("VKC_PROJECT_ID")


def get_token(username: str, password: str, project_id: str,
              user_domain_name: str = "users") -> str:
    headers = {
        "Content-Type": "application/json",
        # "User-Agent": "openstacksdk/4.5.0 keystoneauth1/5.11.1 python-requests/2.32.5 CPython/3.9.6",
        # "Accept-Encoding": "gzip, deflate, br",
        # "Accept": "application/json"
    }

    auth_payload = {
        "auth":
            {
                "identity":
                    {
                        "methods": ["password"],
                        "password": {
                            "user": {
                                "password": password,
                                "name": username,
                                # Личные УЗ — домен "users", сервисные —
                                # "service-users" (см. openrc сервисной УЗ).
                                "domain":
                                    {
                                        "name": user_domain_name
                                    }
                            }
                        }
                    },
                "scope":
                    {
                        "project":
                            {
                                "id": project_id,
                            }
                    }
            }
    }
    with httpx.Client(headers=headers) as client:
        # url = "/"
        # r = client.get(f"{AUTH_URL}{url}")
        # print(r)
        url = "/auth/tokens"
        r = client.post(f"{AUTH_URL}{url}", json=auth_payload)
        token = r.headers.get('X-Subject-Token')
        if not token:
            raise RuntimeError(
                f"VK Cloud auth failed: HTTP {r.status_code}, {r.text[:200]}")
        return token


def get_vms(token):
    """
    https://cloud.vk.com/docs/ru/tools-for-using-services/api/api-spec/iaas-api/nova-api#/servers
    """
    url = f"{NOVA_ENDPOINT}/servers/detail"
    vms = []
    headers = {
        "Content-Type": "application/json",
        "X-Auth-Token": token,
    }
    params = {
        "limit": 50,
        # "marker": "0",
        "sort_key": "created_at",
    }
    with httpx.Client(headers=headers) as client:
        try:
            r = client.get(url, params=params)
            vms.extend(r.json().get('servers'))
            while r.json().get('servers_links'):
                url = r.json().get('servers_links')[0].get('href')
                r = client.get(url)
                vms.extend(r.json().get('servers'))
        except Exception as e:
            logger.error(e)
            raise
    return vms


def transform_vms(vms_all: list) -> list:
    transformed = []
    for vm in vms_all:
        id = vm.get('id')
        tenant_id = vm.get('tenant_id')
        name = vm.get('name').lower()
        status = vm.get('status')
        addresses = vm.get('addresses')
        # ip_addresses = [for ip in port for network, port in addresses.items() ]
        ip_addresses = []
        for network, ports in addresses.items():
            for port in ports:
                ip = port.get('addr')
                ip_addresses.append(ip)

        data = {
            "id": id,
            "tenant_id": tenant_id,
            "name": name,
            # hostname внутри ОС ('OS-EXT-SRV-ATTR:hostname') у VK Cloud недоступен:
            # максимальная microversion Nova здесь 2.42, поле появляется с 2.90 (всё
            # выше — HTTP 406), и у не-админской учётки ключей 'OS-EXT-SRV-ATTR:*' нет
            # вовсе. Поэтому имя ВМ — единственный источник, а расхождение с реальным
            # hostname гасится нормализацией '_' -> '-' в merge3.
            "hostname": name,
            "status": status,
            # Строкой через запятую, как в sbercloud-adv.py: список ушёл бы в CSV
            # питоновским репром ("['10.0.2.19']"), а по нему не работают ни
            # матчинг по IP в merge3, ни исключения по ips в exclusions.yaml.
            "sourceip": ",".join(ip_addresses),
            # пусто = обычная ВМ; иначе тип managed-сервиса, агент невозможен
            "managed": managed_kind(vm.get("metadata")),
        }


        transformed.append(data)
    return transformed


def load_companies() -> list[dict]:
    """Список тенантов VK Cloud из vkcloud_config.yaml.

    Формат:
      companies:
        - name: project-a
          username: user@example.com
          password: secret
          project_id: <id>

    Если файла нет — один тенант из переменных окружения (VKC_USERNAME/PASSWORD/
    PROJECT_ID, имя из VKC_COMPANY или 'project-a'). Так ручной прогон с ноутбука
    работает как раньше, а контейнер берёт список из смонтированного конфига.
    """
    path = CONFIG_DIR / "vkcloud_config.yaml"
    if path.exists():
        data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
        return data.get("companies") or []
    if VKC_USERNAME and VKC_PASSWORD and VKC_PROJECT_ID:
        return [{
            "name": os.environ.get("VKC_COMPANY", "project-a"),
            "username": VKC_USERNAME, "password": VKC_PASSWORD,
            "project_id": VKC_PROJECT_ID,
        }]
    logger.warning("нет ни %s, ни VKC_* в окружении — тенантов VK Cloud нет", path)
    return []


def extract_company(company: dict) -> None:
    name = company["name"]
    token = get_token(username=company["username"], password=company["password"],
                      project_id=company["project_id"],
                      user_domain_name=company.get("user_domain_name", "users"))
    vms_all = get_vms(token=token)
    vms_transformed = transform_vms(vms_all)
    df_vm = pd.DataFrame.from_records(vms_transformed)
    if df_vm.empty:
        # см. sbercloud-adv.py: пустой результат не должен затирать прошлый CSV
        logger.warning("[%s] пустой список ВМ — CSV не перезаписываю (оставляю прошлый)", name)
        return
    df_vm['company'] = name
    managed = df_vm[df_vm['managed'] != '']
    logger.info("[%s] ВМ всего: %d, из них managed (агент невозможен): %d %s",
                name, len(df_vm), len(managed),
                dict(managed['managed'].value_counts()) if len(managed) else "")
    df_vm.to_csv(DATA_DIR / f"{name}-vkcloud.csv", index=False)


def main():
    for company in load_companies():
        extract_company(company)


if __name__ == '__main__':
    logging.basicConfig(format='%(asctime)s - %(name)s - %(levelname)s - %(message)s', level=logging.INFO)
    main()
