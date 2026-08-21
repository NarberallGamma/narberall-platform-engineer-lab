"""certbot → kubectl (SA token) → nginx SSH → опционально https_verification."""

from __future__ import annotations

from pathlib import Path
from typing import List, Optional, Tuple

from cert_paths import pem_paths
from certbot_run import run_certbot
from config import OrchestratorConfig
from deploy_results import TargetDeployResult, results_to_step_lines, summarize
from https_verify import HttpsCheckResult, results_to_log_lines, run_all
from k8s_tls import deploy_wildcard_tls
from logging_setup import get_logger
from notify_telegram import (
    notify_next_rotation_reminder,
    notify_renewal_error,
    notify_renewal_finished,
    notify_renewal_started,
)
from regru_ini import resolve_regru_credentials_path
from ssh_remote import deploy_nginx_hosts
from state import record_renewal_attempt


def certbot_regru_credentials_cli(cfg: OrchestratorConfig) -> list[str]:
    """`--dns-credentials` и путь к INI (Certbot 3.x; см. certbot_run.build_certbot_cmd)."""
    p: Path = resolve_regru_credentials_path(cfg.letsencrypt)
    return ["--dns-credentials", str(p)]


def _ssh_timeout(cfg: OrchestratorConfig) -> int:
    return max(
        int(cfg.timeouts.ssh_connect_seconds),
        int(cfg.timeouts.ssh_command_seconds),
        60,
    )


def _https_telegram_rows(results: List[HttpsCheckResult]) -> List[Tuple[str, bool, str, str]]:
    rows: List[Tuple[str, bool, str, str]] = []
    for r in results:
        hp = f"{r.host}:{r.port}"
        na = ""
        if r.not_after:
            na = r.not_after.strftime("%d.%m.%Y %H:%M:%S UTC")
        elif r.message:
            na = r.message[:200]
        fp = r.fingerprint_sha256 or ""
        rows.append((hp, r.ok, na, fp))
    return rows


def _log_target_results(logger, results: List[TargetDeployResult]) -> None:
    for r in results:
        status = "OK" if r.ok else "FAIL"
        detail = f" — {r.detail}" if r.detail else ""
        logger.info("[%s] %s %s%s", status, r.kind, r.target_id, detail)


def _collect_state_results(
    k8s_results: List[TargetDeployResult],
    nginx_results: List[TargetDeployResult],
    https_results: List[HttpsCheckResult],
) -> list[dict]:
    out: list[dict] = []
    for r in k8s_results + nginx_results:
        out.append(r.to_state_dict())
    for r in https_results:
        out.append(
            {
                "kind": "HTTPS",
                "target_id": f"{r.host}:{r.port}",
                "ok": r.ok,
                "detail": r.message[:500],
            }
        )
    return out


def run_renewal(cfg: OrchestratorConfig, force_renewal: bool = False) -> int:
    logger = get_logger()
    logger.info("Конвейер renewal: старт%s", " (certbot --force-renewal)" if force_renewal else "")
    step_lines: List[Tuple[str, bool, str]] = []
    target_results: List[TargetDeployResult] = []

    try:
        resolve_regru_credentials_path(cfg.letsencrypt)
    except Exception as e:
        logger.error("REG.RU credentials: %s", e)
        notify_renewal_error(cfg, "REG.RU credentials", str(e))
        record_renewal_attempt(success=False, partial=False, target_results=[])
        return 1

    notify_renewal_started(cfg)

    try:
        rc = run_certbot(cfg, force_renewal=force_renewal)
    except RuntimeError as e:
        logger.error("certbot: %s", e)
        notify_renewal_error(cfg, "Certbot", str(e))
        record_renewal_attempt(success=False, partial=False, target_results=[])
        return 1
    if rc != 0:
        logger.error("certbot завершился с кодом %s", rc)
        notify_renewal_error(cfg, "Certbot", f"exit code {rc}")
        record_renewal_attempt(success=False, partial=False, target_results=[])
        return rc
    step_lines.append(("Certbot", True, ""))

    cert_path, key_path = pem_paths(cfg.letsencrypt)
    if not cert_path.is_file() or not key_path.is_file():
        logger.error("После certbot нет PEM: %s / %s", cert_path, key_path)
        notify_renewal_error(cfg, "PEM", f"нет файлов: {cert_path} / {key_path}")
        record_renewal_attempt(success=False, partial=False, target_results=[])
        return 1

    https_rows: Optional[List[Tuple[str, bool, str, str]]] = None
    https_results: List[HttpsCheckResult] = []

    try:
        if cfg.kubernetes.enabled:
            k8s_results = deploy_wildcard_tls(cfg)
            target_results.extend(k8s_results)
            _log_target_results(logger, k8s_results)
            step_lines.extend(results_to_step_lines(k8s_results))
            ok_n, total_n = summarize(k8s_results)
            if total_n == 0:
                step_lines.append(("Kubernetes", True, "нет targets"))
            elif ok_n == total_n:
                logger.info("kubectl TLS secret: OK (%s namespace(s))", total_n)
            elif ok_n > 0:
                logger.warning(
                    "kubectl TLS secret: частично (%s/%s OK)", ok_n, total_n
                )
            else:
                logger.error("kubectl TLS secret: все %s namespace(s) failed", total_n)
        else:
            step_lines.append(("Kubernetes", True, "выключено"))

        if cfg.targets.nginx_remotes.enabled:
            nginx_results = deploy_nginx_hosts(cfg, cert_path, key_path, _ssh_timeout(cfg))
            target_results.extend(nginx_results)
            _log_target_results(logger, nginx_results)
            step_lines.extend(results_to_step_lines(nginx_results))
            ok_n, total_n = summarize(nginx_results)
            if total_n == 0:
                step_lines.append(("nginx", True, "нет хостов"))
            elif ok_n == total_n:
                logger.info("nginx remotes: OK (%s host(s))", total_n)
            elif ok_n > 0:
                logger.warning("nginx remotes: частично (%s/%s OK)", ok_n, total_n)
            else:
                logger.error("nginx remotes: все %s host(s) failed", total_n)
        else:
            step_lines.append(("nginx", True, "выключено"))

        if cfg.https_verification.enabled:
            https_results = run_all(cfg)
            for line in results_to_log_lines(https_results):
                logger.info("https: %s", line)
            https_rows = _https_telegram_rows(https_results)
            for r in https_results:
                step_lines.append(
                    (
                        f"HTTPS {r.host}:{r.port}",
                        r.ok,
                        r.message[:200] if not r.ok else "",
                    )
                )
            if https_results and not all(r.ok for r in https_results):
                failed = sum(1 for r in https_results if not r.ok)
                logger.warning("HTTPS-проверка: %s/%s сбоев", failed, len(https_results))
        else:
            step_lines.append(("HTTPS-проверки", True, "выключено"))

    except FileNotFoundError as e:
        logger.error("%s", e)
        notify_renewal_error(cfg, "Файл/ключ", str(e))
        record_renewal_attempt(
            success=False,
            partial=False,
            target_results=[r.to_state_dict() for r in target_results],
        )
        return 1
    except RuntimeError as e:
        logger.error("Конвейер: %s", e)
        notify_renewal_error(cfg, "Конвейер", str(e))
        record_renewal_attempt(
            success=False,
            partial=bool(target_results and any(r.ok for r in target_results)),
            target_results=_collect_state_results(
                [r for r in target_results if r.kind == "Kubernetes"],
                [r for r in target_results if r.kind == "nginx"],
                https_results,
            ),
        )
        return 1
    except Exception as e:
        logger.exception("Конвейер: непредвиденная ошибка: %s", e)
        notify_renewal_error(cfg, "Конвейер", str(e))
        record_renewal_attempt(
            success=False,
            partial=bool(target_results and any(r.ok for r in target_results)),
            target_results=[r.to_state_dict() for r in target_results],
        )
        return 1

    deploy_steps = [line for line in step_lines if line[0] != "Certbot"]
    any_deploy_fail = any(not ok for _, ok, _ in deploy_steps) if deploy_steps else False
    full_success = all(ok for _, ok, _ in step_lines)
    partial = any_deploy_fail and any(ok for _, ok, _ in step_lines)

    state_payload = _collect_state_results(
        [r for r in target_results if r.kind == "Kubernetes"],
        [r for r in target_results if r.kind == "nginx"],
        https_results,
    )

    notify_renewal_finished(cfg, step_lines, https_rows, partial=partial, full_success=full_success)
    if full_success:
        notify_next_rotation_reminder(cfg)

    if full_success:
        logger.info("Конвейер renewal: успешно")
    elif partial:
        logger.warning("Конвейер renewal: частичный успех")
    else:
        logger.error("Конвейер renewal: certbot OK, раскладка не удалась")

    record_renewal_attempt(
        success=full_success,
        partial=partial,
        target_results=state_payload,
    )
    return 0 if full_success else 1
