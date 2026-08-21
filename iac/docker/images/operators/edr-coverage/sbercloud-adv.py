import collections
import logging
import os
import re
import json
import yaml
import pandas as pd
from pathlib import Path
from typing import Any

from huaweicloudsdkcore.auth.credentials import BasicCredentials, DerivedCredentials
from huaweicloudsdkcore.exceptions import exceptions
from huaweicloudsdkcore.http.http_config import HttpConfig

from huaweicloudsdkiam.v3 import IamClient, KeystoneListProjectsRequest
from huaweicloudsdkecs.v2 import EcsClient, ListServersDetailsRequest


# global http config
config = HttpConfig.get_default_config()
config.ignore_ssl_verification = True
config.timeout = 240
# urllib3.disable_warnings(InsecureRequestWarning)

# Конфиг — из EDR_CONFIG_DIR (в контейнере read-only каталог с секретами из
# SOPS); выгрузки — в EDR_DATA_DIR. По умолчанию текущий каталог (ручной прогон).
CONFIG_DIR = Path(os.environ.get("EDR_CONFIG_DIR", "."))
DATA_DIR = Path(os.environ.get("EDR_DATA_DIR", "."))


def load_companies(config_path: Path = None) -> list[dict]:
    path = Path(config_path) if config_path else CONFIG_DIR / "sbc-adv_config.yaml"
    if not path.exists():
        raise FileNotFoundError(f"Файл конфигурации не найден: {path.resolve()}")
    with path.open("r", encoding="utf-8") as f:
        data = yaml.safe_load(f)
    return data["companies"]


def extract_sbercloud_adv(company):
    company_name, ak, sk, sts, extra = company['name'], company['ak'], company['sk'], company.get('sts', None), company['extra']

    projects_ids, all_iam_projects = get_projects(
        ak=ak,
        sk=sk,
        root_project_id=extra['root_project_id'],
        endpoint_iam=extra['endpoint_iam'],
        **({"sts": sts} if sts is not None else {})
    )
    ecs_list = get_ecs_from_each_project(
        ak=ak,
        sk=sk,
        projects=projects_ids,
        endpoint_ecs=extra['endpoint_ecs'],
        enterprise_project_id=company.get('enterprise_project_id'),
        **({"sts": sts} if sts is not None else {})
    )
    # eip_list = get_eip_from_each_project(ak=ak, sk=sk, projects=projects_ids, endpoint_vpc=extra['endpoint_vpc'])
    df_vm = prepare_df_vm(ecs_list)
    if df_vm.empty:
        # Пустой результат = провал доступа (403/протухший токен) или реально 0 ВМ.
        # НЕ перезаписываем старый CSV пустым: иначе разовый сбой облака стирает
        # инвентарь из покрытия. Оставляем прошлую выгрузку.
        logging.warning("[%s] пустой результат ECS — CSV не перезаписываю (оставляю прошлый)", company_name)
        return
    df_vm['company'] = company_name
    df_vm.to_csv(DATA_DIR / f"{company_name}-sbc-adv.csv", index=False, )
    # df_eip = prepare_df_eip(all_iam_projects, eip_list)


def get_projects(ak, sk, root_project_id, endpoint_iam, sts=None) -> tuple[dict[Any, Any], list[dict[str, str | Any]]]:
    all_iam_projects = []
    cloud = {'cloud_id': root_project_id, 'cloud_name': "ru-moscow-1"}

    if sts:
        credentials = BasicCredentials(ak, sk, root_project_id).with_security_token(sts)
    else:
        credentials = BasicCredentials(ak, sk, root_project_id)

    projects_ids = {}
    iam_client = IamClient.new_builder() \
        .with_http_config(config) \
        .with_credentials(credentials) \
        .with_endpoint(endpoint_iam) \
        .build()
    try:
        request = KeystoneListProjectsRequest()
        projects = iam_client.keystone_list_projects(request)
        for project in projects.projects:
            if project.enabled is True and project.name != "MOS":
                projects_ids[project.id] = project.name
                project_info = {
                    'id': project.id,
                    'name': project.name,
                    'cloud_id': cloud['cloud_id'],
                    'cloud_name': cloud['cloud_name']
                }
                all_iam_projects.append(project_info)
    except exceptions.ClientRequestException as e:
        logging.error(f"Ошибка получения проектов из облака по API, Статус-код  запроса: {e.status_code},"
              f" ID-запроса: {e.request_id}, Код ошибки: {e.error_code}, Сообщение об ошибке: {e.error_msg}")
    return projects_ids, all_iam_projects


def get_ecs_from_each_project(ak: str, sk: str, projects: dict, endpoint_ecs: str,
                              sts=None, enterprise_project_id=None) -> list:
    # enterprise_project_id управляет тем, по какому scope проверяются права:
    #   не задан (None)   — по IAM-проекту (региональному), права выданы на него;
    #   "all_granted_eps" — по всем enterprise-проектам, где у учётки есть роли;
    #   "<id>" / "0"      — по конкретному enterprise-проекту ("0" — default).
    # Выбор — под модель раздачи прав в IAM SberCloud (см. sbc-adv_config.yaml).
    ecs_list = []
    for project_id, project_name in projects.items():
        # credentials = BasicCredentials(ak, sk, project_id)
        if sts:
            credentials = BasicCredentials(ak, sk, project_id).with_security_token(sts)
        else:
            credentials = BasicCredentials(ak, sk, project_id)

        ecs_client = EcsClient.new_builder() \
            .with_http_config(config) \
            .with_credentials(credentials) \
            .with_endpoint(endpoint_ecs) \
            .build()
        offset = 1
        while True:
            request = ListServersDetailsRequest(limit=100, offset=offset)
            if enterprise_project_id:
                request.enterprise_project_id = enterprise_project_id
            response = ecs_client.list_servers_details(request)
            vm_count = len(response.servers)
            try:
                for server in response.servers:
                    # server.tags = tags_converter_ecs(server.tags)
                    server.tags = {tag.split("=")[0]: tag.split("=")[-1] for tag in server.tags}
                    server_obj_str = str(server)
                    # FILTER USER DATA -> CLOUD INIT
                    server_obj_str_filtered = re.sub(r':user_data":\s".*?"', ':user_data": "FILTERED"', server_obj_str)
                    server_obj = json.loads(server_obj_str_filtered)
                    server_obj['folderId'] = project_id
                    server_obj['folder_name'] = project_name
                    ecs_list.append(server_obj)
            except exceptions.ClientRequestException as e:
                logging.error(f"Ошибка получения данных по ECS из облака по API, Статус-код  запроса: {e.status_code},"
                              f" ID-запроса: {e.request_id}, Код ошибки: {e.error_code}, Сообщение об ошибке: {e.error_msg}")

            logging.info(f"IAM-проект: {project_name}, со страницы {offset} получено ВМ: {vm_count}")
            if vm_count == 0:
                break
            else:
                offset += 1
    return ecs_list


# Теги ECS, которыми SberCloud помечает ноды managed-сервисов (тег -> тип).
# Агент на такие ноды поставить нельзя, в покрытии они только занижают процент.
# CCE-Cluster-ID подтверждён на живых данных; остальные managed-сервисы
# (RDS, DDS) в списке ECS не появляются — если появится что-то ещё, оно всплывёт
# в логе "теги ECS в выгрузке" ниже, и маркер добавляется сюда одной строкой.
MANAGED_TAG_KEYS = {
    'CCE-Cluster-ID': 'kubernetes',
}


def managed_kind(tags) -> str:
    """Тип managed-сервиса по тегам ВМ; пустая строка — обычная ВМ."""
    tags = tags or {}
    for tag_key, kind in MANAGED_TAG_KEYS.items():
        if tag_key in tags:
            return kind
    return ''


def prepare_df_vm(sbca_vms):
    vms_result = []
    logging.info(
        f"Количество виртуальных машин полученных по API в SBCA: {len(sbca_vms)}")
    # Разведка: полный набор ключей тегов в выгрузке. Нужен, чтобы маркеры
    # managed добавлялись по факту, а не угадывались.
    all_tag_keys = sorted({key for vm in sbca_vms for key in (vm.get('tags') or {})})
    logging.info(f"Теги ECS в выгрузке: {all_tag_keys}")
    for sbca_vm in sbca_vms:
        # Ноды managed-сервисов раньше молча выбрасывались; теперь помечаются —
        # из покрытия их исключит merge3, но в отчёте и метриках они видимы.
        managed = managed_kind(sbca_vm.get('tags'))
        vm = {
            'id': sbca_vm['id'],
            'dc': 'SBCA',
            'iam': sbca_vm['folder_name'],
            'hostname': sbca_vm['name'].lower(),
            # hostname внутри ОС: cloud-init правит имя ВМ под RFC 1123
            # ('ecs-corp-mfa_radius-az1-01' -> 'ecs-corp-mfa-radius-az1-01'), и агент
            # регистрируется уже под изменённым именем. Ключ в ответе API — wire-имя
            # 'OS-EXT-SRV-ATTR:hostname' (заполнено у всех 172 ВМ на 2026-08-12);
            # 'os_ext_srv_att_rhostname' — это имя атрибута SDK, после json.loads(str(server))
            # его нет. Поле фиксируется при создании ВМ и не следует за переименованием
            # инстанса, поэтому оно дополняет 'hostname', а не заменяет его.
            'os_hostname': str(sbca_vm.get('OS-EXT-SRV-ATTR:hostname') or '').strip().lower(),
            'os_type': sbca_vm['metadata']['os_type'],
            'status': sbca_vm['status'],
            'link': f"https://console.hc.sbercloud.ru/ecm/?region={sbca_vm['folder_name']}"
                    f"&locale=en-us#/ecs/manager/vmList/vmDetail/basicinfo?"
                    f"instanceId={sbca_vm['id']}",
            'sourceip': ','.join([ip_addr['addr'] for ip_addresses in sbca_vm['addresses'].values()
                                  for ip_addr in ip_addresses]),
            'managed': managed,
        }
        vms_result.append(vm)
    managed_count = collections.Counter(vm['managed'] for vm in vms_result if vm['managed'])
    logging.info(f"Виртуальных машин: {len(vms_result)}, "
                 f"из них managed (агент невозможен): {sum(managed_count.values())} {dict(managed_count)}")
    df = pd.DataFrame.from_records(vms_result)
    return df


def main():
    companies = load_companies()
    for company in companies:
        extract_sbercloud_adv(company)


if __name__ == "__main__":
    main()
