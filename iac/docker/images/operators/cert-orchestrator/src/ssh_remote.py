"""SCP/SSH: раскладка PEM и удалённые команды (openssh-client в образе)."""

from __future__ import annotations

import secrets
import shlex
import subprocess
from pathlib import Path
from typing import List

from config import NginxHostConfig, OrchestratorConfig
from deploy_results import TargetDeployResult


def _ssh_base(identity: str, user: str, host: str) -> List[str]:
    return [
        "ssh",
        "-i",
        identity,
        "-o",
        "BatchMode=yes",
        "-o",
        "StrictHostKeyChecking=accept-new",
        f"{user}@{host}",
    ]


def _scp_to(
    identity: str,
    user: str,
    host: str,
    local: Path,
    remote: str,
    timeout: int,
) -> tuple[int, str]:
    r = subprocess.run(
        [
            "scp",
            "-i",
            identity,
            "-o",
            "BatchMode=yes",
            "-o",
            "StrictHostKeyChecking=accept-new",
            str(local),
            f"{user}@{host}:{remote}",
        ],
        capture_output=True,
        timeout=timeout,
    )
    err = (r.stderr or r.stdout or b"").decode(errors="replace").strip()
    return r.returncode, err


def _ssh_script(
    identity: str, user: str, host: str, script: str, timeout: int
) -> tuple[int, str]:
    r = subprocess.run(
        _ssh_base(identity, user, host) + ["bash", "-s"],
        input=script.encode(),
        capture_output=True,
        timeout=timeout,
    )
    err = (r.stderr or r.stdout or b"").decode(errors="replace").strip()
    return r.returncode, err


def _dest_names(domain: str, cert_basename: str) -> tuple[str, str]:
    base = (cert_basename or "").strip() or domain.strip()
    return f"{base}.crt", f"{base}.key"


NGINX_RELOAD_AUTODETECT = """case "$DEST_DIR" in
  /docker/apps/*/certs)
    if [ -z "${NGINX_CONTAINER:-}" ]; then
      NGINX_CONTAINER="${DEST_DIR#/docker/apps/}"
      NGINX_CONTAINER="${NGINX_CONTAINER%/certs}"
    fi
    sudo docker exec "$NGINX_CONTAINER" nginx -t
    sudo docker exec "$NGINX_CONTAINER" nginx -s reload
    ;;
  *)
    sudo nginx -t
    sudo systemctl reload nginx 2>/dev/null || sudo nginx -s reload
    ;;
esac"""


def _deploy_nginx_host_one(
    cfg: OrchestratorConfig,
    host_cfg: NginxHostConfig,
    cert_path: Path,
    key_path: Path,
    timeout_ssh: int,
) -> TargetDeployResult:
    domain = cfg.letsencrypt.domain.strip()
    h = (host_cfg.host or "").strip()
    target_id = h or "(empty host)"

    if not h:
        return TargetDeployResult("nginx", target_id, False, "пустой host")

    cert_name, key_name = _dest_names(domain, host_cfg.cert_basename)
    identity = host_cfg.identity_file
    if not identity or not Path(identity).is_file():
        return TargetDeployResult("nginx", target_id, False, f"SSH identity не найден: {identity}")

    u = host_cfg.user or "root"
    dest_dir = host_cfg.ssl_dir.rstrip("/")
    staging = f"/tmp/ssl-co-staging-{secrets.token_hex(8)}"

    try:
        rc, err = _ssh_script(
            identity,
            u,
            h,
            f"rm -rf {shlex.quote(staging)} && mkdir -p {shlex.quote(staging)} && chmod 700 {shlex.quote(staging)}",
            timeout_ssh,
        )
        if rc:
            return TargetDeployResult("nginx", target_id, False, err[:500] or "mkdir staging failed")

        rc, err = _scp_to(identity, u, h, cert_path, f"{staging}/fullchain.pem", timeout_ssh)
        if rc:
            return TargetDeployResult("nginx", target_id, False, err[:500] or "scp cert failed")

        rc, err = _scp_to(identity, u, h, key_path, f"{staging}/privkey.pem", timeout_ssh)
        if rc:
            return TargetDeployResult("nginx", target_id, False, err[:500] or "scp key failed")

        nginx_container_line = ""
        nginx_container = (host_cfg.nginx_container or "").strip()
        if nginx_container:
            nginx_container_line = f"NGINX_CONTAINER={shlex.quote(nginx_container)}\n"

        script = f"""set -e
{nginx_container_line}STAGING={shlex.quote(staging)}
DEST_DIR={shlex.quote(dest_dir)}
CERT_NAME={shlex.quote(cert_name)}
KEY_NAME={shlex.quote(key_name)}
sudo mkdir -p "$DEST_DIR"
sudo install -m 644 "$STAGING/fullchain.pem" "$DEST_DIR/$CERT_NAME"
sudo install -m 600 "$STAGING/privkey.pem" "$DEST_DIR/$KEY_NAME"
sudo rm -rf "$STAGING"
{NGINX_RELOAD_AUTODETECT}
"""
        rc, err = _ssh_script(identity, u, h, script, timeout_ssh)
        if rc:
            return TargetDeployResult("nginx", target_id, False, err[:500] or "install/reload failed")

        return TargetDeployResult("nginx", target_id, True, dest_dir)
    except subprocess.TimeoutExpired:
        return TargetDeployResult("nginx", target_id, False, "timeout")
    except Exception as exc:
        return TargetDeployResult("nginx", target_id, False, str(exc)[:500])


def deploy_nginx_hosts(
    cfg: OrchestratorConfig,
    cert_path: Path,
    key_path: Path,
    timeout_ssh: int,
) -> List[TargetDeployResult]:
    """Раскладка PEM на nginx targets; ошибка одного хоста не прерывает остальные."""
    nr = cfg.targets.nginx_remotes
    if not nr.enabled:
        return []

    results: List[TargetDeployResult] = []
    for host_cfg in nr.hosts:
        if not (host_cfg.host or "").strip():
            continue
        results.append(
            _deploy_nginx_host_one(cfg, host_cfg, cert_path, key_path, timeout_ssh)
        )
    return results
