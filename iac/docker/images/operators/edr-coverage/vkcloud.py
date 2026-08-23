import logging
import os
import httpx
import json
from pathlib import Path

import pandas as pd
import yaml

AUTH_URL = "https://infra.mail.ru:35357/v3"
NOVA_ENDPOINT = "https://infra.mail.ru:8774/v2.1"

# Config from EDR_CONFIG_DIR (in the container a read-only SOPS directory); exports
# go to EDR_DATA_DIR. Defaults to the current directory (manual run from a laptop).
CONFIG_DIR = Path(os.environ.get("EDR_CONFIG_DIR", "."))
DATA_DIR = Path(os.environ.get("EDR_DATA_DIR", "."))

# Managed resources (managed DB nodes, managed Kubernetes, etc.) appear in the
# Nova list as ordinary VMs, but an EDR agent cannot be installed on them — they
# only lower the coverage percentage. VK Cloud marks them with metadata.
#
# Keys whose mere presence means a managed resource (key -> kind):
MANAGED_METADATA_KEYS = {
    "datastore": "database",         # managed DB: datastore/datastore_version
    "mcs_cluster_id": "kubernetes",  # managed Kubernetes (MKS) nodes
    "k8s_cluster_id": "kubernetes",
}
# Key+value pairs (the key alone is not enough):
MANAGED_METADATA_VALUES = {"sid": {"trove": "database"}}
#
# IMPORTANT: service_user_id is NOT usable for this — ordinary VMs have it
# (46 of 71 in project-a); filtering on it would drop a third of the estate.


def managed_kind(metadata: dict) -> str:
    """Managed-service kind from VM metadata; empty string is an ordinary VM."""
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
                                # Personal accounts use domain "users"; service
                                # accounts use "service-users" (see the service openrc).
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
            # In-guest hostname ('OS-EXT-SRV-ATTR:hostname') is unavailable on VK Cloud:
            # the highest Nova microversion here is 2.42, the field appears in 2.90
            # (anything higher is HTTP 406), and a non-admin account has no
            # 'OS-EXT-SRV-ATTR:*' keys at all. The VM name is therefore the only
            # source; mismatch with the real hostname is absorbed by '_' -> '-'
            # normalization in merge3.
            "hostname": name,
            "status": status,
            # Comma-separated string, as in sbercloud-adv.py: a list would land in CSV
            # as a Python repr ("['10.0.2.19']"), which breaks both IP matching in
            # merge3 and ip exclusions in exclusions.yaml.
            "sourceip": ",".join(ip_addresses),
            # empty = ordinary VM; otherwise a managed-service kind, agent impossible
            "managed": managed_kind(vm.get("metadata")),
        }


        transformed.append(data)
    return transformed


def load_companies() -> list[dict]:
    """VK Cloud tenants from vkcloud_config.yaml.

    Format:
      companies:
        - name: project-a
          username: user@example.com
          password: secret
          project_id: <id>

    If the file is missing — one tenant from environment variables
    (VKC_USERNAME/PASSWORD/PROJECT_ID, name from VKC_COMPANY or 'project-a').
    A manual laptop run then works as before, and the container reads the
    list from the mounted config.
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
    logger.warning("neither %s nor VKC_* in the environment — no VK Cloud tenants", path)
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
        # see sbercloud-adv.py: an empty result must not overwrite the previous CSV
        logger.warning("[%s] empty VM list — leaving the previous CSV in place", name)
        return
    df_vm['company'] = name
    managed = df_vm[df_vm['managed'] != '']
    logger.info("[%s] VMs total: %d, of which managed (agent impossible): %d %s",
                name, len(df_vm), len(managed),
                dict(managed['managed'].value_counts()) if len(managed) else "")
    df_vm.to_csv(DATA_DIR / f"{name}-vkcloud.csv", index=False)


def main():
    for company in load_companies():
        extract_company(company)


if __name__ == '__main__':
    logging.basicConfig(format='%(asctime)s - %(name)s - %(levelname)s - %(message)s', level=logging.INFO)
    main()
