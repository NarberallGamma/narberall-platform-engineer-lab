#!/usr/bin/env python3
"""
Точка входа cert-orchestrator: daemon | renew | verify-https
"""

from __future__ import annotations

import argparse
import os
import signal
import sys
import time

from config import load_config
from https_verify import results_to_log_lines, run_all
from logging_setup import get_logger, setup_logging
from notify_telegram import notify_startup, telegram_enabled
from pipeline import run_renewal
from regru_ini import RegruCredentialsError, resolve_regru_credentials_path
from scheduler import should_run_renewal


def _log_regru_creds(cfg, logger) -> None:
    try:
        creds_path = resolve_regru_credentials_path(cfg.letsencrypt)
        if str(creds_path).startswith("/run/cert-orchestrator"):
            logger.info("REG.RU DNS: INI сформирован из env → %s", creds_path)
    except RegruCredentialsError as e:
        logger.warning(
            "REG.RU DNS: %s — выпуск certbot будет невозможен до настройки REG_RU_DNS_USERNAME "
            "и REG_RU_DNS_PASSWORD в .env контейнера",
            e,
        )


def cmd_daemon(cfg, config_path: str) -> int:
    setup_logging(cfg)
    logger = get_logger()

    logger.info("=== cert-orchestrator старт (daemon) ===")
    logger.info("Окружение: %s | конфиг: %s", cfg.meta.environment, config_path)
    _log_regru_creds(cfg, logger)

    if telegram_enabled(cfg):
        logger.info("Telegram: проверка при отправке startup-уведомления (getMe пропущен)")
        notify_startup(cfg)

    running = True

    def _stop(*_args):
        nonlocal running
        running = False
        logger.info("Получен сигнал завершения")

    signal.signal(signal.SIGINT, _stop)
    signal.signal(signal.SIGTERM, _stop)

    poll = max(60, cfg.schedule.poll_interval_seconds)
    tick = min(60, max(10, poll))
    skip_scheduled_once = False
    if cfg.schedule.renew_on_container_start:
        logger.info("Старт контейнера: запуск renewal (renew_on_container_start=true)")
        rc = run_renewal(cfg)
        logger.info("renewal на старте завершён с кодом %s", rc)
        skip_scheduled_once = True

    while running:
        if should_run_renewal(cfg):
            if skip_scheduled_once:
                logger.info(
                    "Пропуск окна расписания: renewal уже выполнен на старте контейнера"
                )
                skip_scheduled_once = False
            else:
                logger.info("Расписание: запуск renewal")
                rc = run_renewal(cfg)
                logger.info("renewal завершён с кодом %s", rc)
        logger.debug("Следующая проверка расписания через %s с", tick)
        for _ in range(tick):
            if not running:
                break
            time.sleep(1)
        if not running:
            break

    logger.info("cert-orchestrator остановлен")
    return 0


def cmd_renew(cfg, config_path: str, force_renewal: bool = False) -> int:
    setup_logging(cfg)
    logger = get_logger()
    logger.info("CLI renew | конфиг: %s%s", config_path, " | --force" if force_renewal else "")
    _log_regru_creds(cfg, logger)
    return run_renewal(cfg, force_renewal=force_renewal)


def cmd_verify_https(cfg, config_path: str) -> int:
    setup_logging(cfg)
    logger = get_logger()
    logger.info("CLI verify-https | конфиг: %s", config_path)

    if not cfg.https_verification.enabled:
        logger.warning("https_verification.enabled=false — нечего проверять")
        return 0

    results = run_all(cfg)
    for line in results_to_log_lines(results):
        logger.info("%s", line)

    if any(not r.ok for r in results):
        return 1
    return 0


def main() -> None:
    parser = argparse.ArgumentParser(description="cert-orchestrator")
    parser.add_argument(
        "--config",
        default=os.environ.get("CONFIG_FILE", "/etc/cert-orchestrator/config.yaml"),
        help="Путь к YAML (или CONFIG_FILE)",
    )
    parser.add_argument(
        "command",
        nargs="?",
        default="daemon",
        choices=("daemon", "renew", "verify-https"),
        help="daemon | renew | verify-https",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="С командой renew: принудительный выпуск сертификата (certbot --force-renewal), в обход срока действия",
    )
    args = parser.parse_args()

    cfg = load_config(args.config)

    if args.command == "daemon":
        rc = cmd_daemon(cfg, args.config)
    elif args.command == "renew":
        rc = cmd_renew(cfg, args.config, force_renewal=args.force)
    else:
        rc = cmd_verify_https(cfg, args.config)

    sys.exit(rc)


if __name__ == "__main__":
    main()
