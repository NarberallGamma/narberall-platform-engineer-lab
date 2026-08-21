"""TLS Secret в перечисленных namespace (kubectl + ServiceAccount token)."""

from __future__ import annotations

import os
import subprocess
from pathlib import Path
from typing import List

from cert_paths import pem_paths
from config import OrchestratorConfig
from deploy_results import TargetDeployResult


def _kubectl_cmd(cfg: OrchestratorConfig, *args: str) -> list[str]:
    k8 = cfg.kubernetes
    cmd = ["kubectl"]
    api_server = (k8.api_server or "").strip()
    if not api_server:
        raise RuntimeError("kubernetes.api_server не задан в конфиге")
    cmd.extend(["--server", api_server])

    token = os.environ.get("K8S_TOKEN", "").strip()
    if not token:
        raise RuntimeError("K8S_TOKEN не задан (Vault / .env)")

    cmd.extend(["--token", token])

    ca_path = (k8.ca_cert_path or "").strip()
    if ca_path and Path(ca_path).is_file():
        cmd.extend(["--certificate-authority", ca_path])
    elif k8.insecure_skip_tls_verify:
        cmd.extend(["--insecure-skip-tls-verify"])
    else:
        raise RuntimeError(
            "kubernetes.ca_cert_path не найден и insecure_skip_tls_verify=false"
        )

    cmd.extend(args)
    return cmd


def _deploy_tls_secret_one(
    cfg: OrchestratorConfig,
    *,
    ns: str,
    secret: str,
    cert_path: Path,
    key_path: Path,
    timeout: int,
    env: dict[str, str],
) -> TargetDeployResult:
    target_id = f"{ns}/{secret}"
    create = subprocess.run(
        _kubectl_cmd(
            cfg,
            "create",
            "secret",
            "tls",
            secret,
            f"--cert={cert_path}",
            f"--key={key_path}",
            f"--namespace={ns}",
            "--dry-run=client",
            "-o",
            "yaml",
        ),
        capture_output=True,
        timeout=timeout,
        env=env,
    )
    if create.returncode != 0:
        err = (create.stderr or create.stdout or b"").decode(errors="replace").strip()
        return TargetDeployResult("Kubernetes", target_id, False, err[:500])

    apply = subprocess.run(
        _kubectl_cmd(cfg, "apply", "-f", "-"),
        input=create.stdout,
        timeout=timeout,
        env=env,
    )
    if apply.returncode != 0:
        err = (apply.stderr or apply.stdout or b"").decode(errors="replace").strip()
        return TargetDeployResult("Kubernetes", target_id, False, err[:500])

    return TargetDeployResult("Kubernetes", target_id, True, "")


def deploy_wildcard_tls(cfg: OrchestratorConfig) -> List[TargetDeployResult]:
    """Раскладка TLS secret по namespace; ошибка одного ns не прерывает остальные."""
    if not cfg.kubernetes.enabled:
        return []

    cert_path, key_path = pem_paths(cfg.letsencrypt)
    if not cert_path.is_file() or not key_path.is_file():
        raise FileNotFoundError(f"Нет PEM: {cert_path} / {key_path}")

    targets = list(cfg.kubernetes.namespace_secrets or [])
    if not targets:
        raise RuntimeError(
            "kubernetes.namespace_secrets пуст: задать namespace и secret_name в конфиге"
        )

    timeout = cfg.timeouts.kubectl_seconds
    env = os.environ.copy()
    results: List[TargetDeployResult] = []

    for item in targets:
        ns = (item.namespace or "").strip()
        secret = (item.secret_name or "").strip()
        if not ns or not secret:
            continue
        try:
            results.append(
                _deploy_tls_secret_one(
                    cfg,
                    ns=ns,
                    secret=secret,
                    cert_path=cert_path,
                    key_path=key_path,
                    timeout=timeout,
                    env=env,
                )
            )
        except Exception as exc:
            results.append(
                TargetDeployResult("Kubernetes", f"{ns}/{secret}", False, str(exc)[:500])
            )

    return results
