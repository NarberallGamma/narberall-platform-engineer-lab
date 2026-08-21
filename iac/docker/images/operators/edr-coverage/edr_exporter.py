#!/usr/bin/env python3
"""Prometheus-экспортер покрытия EDR.

Отдаёт метрики покрытия из merge3: агрегаты по компаниям/типам хостов и
детализацию по каждому хосту (какие машины без агента).

Пайплайн ходит в LDAP и облачные API — это минуты, поэтому считать его на
каждый scrape нельзя. Сбор идёт фоновым потоком раз в EDR_COLLECT_INTERVAL,
а /metrics мгновенно отдаёт последний снапшот: серия в VictoriaMetrics
получается непрерывной, а внешние источники опрашиваются редко.

  EDR_DATA_DIR         каталог с CSV и результатами (см. merge3.DATA_DIR)
  EDR_CONFIG_DIR       каталог с конфигами сборщиков (read-only, из SOPS)
  EDR_COLLECT_SOURCES  1 (по умолч.) — гонять сборщики; 0 — только merge по CSV
  EDR_LISTEN           адрес HTTP-сервера, по умолчанию 0.0.0.0:9655
  EDR_COLLECT_INTERVAL период пересчёта в секундах, по умолчанию 6 часов
  EDR_WATCH_INTERVAL   как часто проверять mtime исходных CSV, по умолчанию 60с

--oneshot: посчитать один раз, напечатать метрики в stdout и выйти.
"""

import argparse
import importlib.util
import logging
import os
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import pandas as pd
from prometheus_client import CONTENT_TYPE_LATEST, CollectorRegistry, Gauge, generate_latest

import merge3

log = logging.getLogger("edr_exporter")

LISTEN = os.environ.get("EDR_LISTEN", "0.0.0.0:9655")
COLLECT_INTERVAL = int(os.environ.get("EDR_COLLECT_INTERVAL", str(6 * 3600)))
WATCH_INTERVAL = int(os.environ.get("EDR_WATCH_INTERVAL", "60"))
CONFIG_DIR = Path(os.environ.get("EDR_CONFIG_DIR", "."))
COLLECT_SOURCES = os.environ.get("EDR_COLLECT_SOURCES", "1") not in ("0", "false", "no", "")

# Сборщики источников: (секция, файл-скрипт, конфиг, наличие которого включает
# сбор). Скрипты с дефисом в имени импортируются по пути (обычный import нельзя).
COLLECTORS = [
    ("active_directory", "active-directory.py", "ad_config.yaml"),
    ("vkcloud", "vkcloud.py", "vkcloud_config.yaml"),
    ("sbercloud", "sbercloud-adv.py", "sbc-adv_config.yaml"),
    ("vendor", "vendor-edr.py", "edr_config.json"),
]

# Суффикс файла-источника -> значение метки source. Порядок важен: '_edr'
# проверяется первым, иначе '-ad' не отличить от прочих выгрузок.
SOURCE_SUFFIXES = [
    ("_edr", "edr"),
    ("-ad", "ad"),
    ("-vkcloud", "vkcloud"),
    ("-sbc-adv", "sbercloud"),
]


def _source_kind(stem: str) -> tuple[str, str] | None:
    """('project-a-ad') -> ('project-a', 'ad'); None для незнакомых файлов."""
    for suffix, kind in SOURCE_SUFFIXES:
        if stem.endswith(suffix):
            return stem[: -len(suffix)], kind
    return None


def source_files() -> dict[tuple[str, str], float]:
    """{(company, source): mtime} по всем исходным CSV в каталоге данных."""
    result = {}
    for path in merge3.DATA_DIR.glob("*.csv"):
        if path.name == merge3.OUTPUT_CSV.name:
            continue
        parsed = _source_kind(path.stem)
        if parsed:
            result[parsed] = path.stat().st_mtime
    return result


def edr_export_times() -> dict[str, float]:
    """
    {company: unix-время выгрузки} по колонке lastseenat из *_edr.csv.

    Возраст файла для этого не годится: выгрузка кладётся руками, и обычный
    scp/копирование переставляет mtime на «сейчас» — метрика свежести начинает
    врать ровно там, где она нужна. Максимальный lastseenat берётся из самих
    данных: хоть один агент почти всегда онлайн, поэтому он близок к моменту
    выгрузки и не зависит от того, как файл доехал.
    """
    result = {}
    for path in merge3.DATA_DIR.glob("*_edr.csv"):
        company = path.stem[: -len("_edr")]
        try:
            column = pd.read_csv(path, usecols=["lastseenat"])["lastseenat"]
            latest = pd.to_datetime(column, errors="coerce", utc=True).max()
        except Exception:
            log.warning("[%s] не смог определить время выгрузки EDR", company)
            continue
        if pd.notna(latest):
            result[company] = latest.timestamp()
    return result


class Snapshot:
    """Последний успешно посчитанный результат, отдаваемый на каждый scrape."""

    def __init__(self):
        self._lock = threading.Lock()
        self._body = b""
        self.collected_at = 0.0

    def render(self, frame, overall, duration, errors):
        registry = CollectorRegistry()

        def gauge(name, doc, labels=()):
            return Gauge(name, doc, labels, registry=registry)

        collect_errors = gauge("edr_collect_errors", "1 если секция сбора упала", ["section"])
        for section, failed in errors.items():
            collect_errors.labels(section).set(int(failed))

        gauge("edr_collection_duration_seconds", "Длительность последнего сбора").set(duration)

        source_ts = gauge(
            "edr_source_file_timestamp_seconds",
            "Unix-время последнего изменения файла-источника",
            ["company", "source"],
        )
        for (company, source), mtime in source_files().items():
            source_ts.labels(company, source).set(mtime)

        export_ts = gauge(
            "edr_source_data_timestamp_seconds",
            "Unix-время выгрузки по данным внутри неё (не по mtime файла)",
            ["company", "source"],
        )
        for company, ts in edr_export_times().items():
            export_ts.labels(company, "edr").set(ts)

        if overall:
            hosts_total = gauge(
                "edr_hosts_total", "Хостов в пуле подсчёта", ["company", "host_type"]
            )
            hosts_with_agent = gauge(
                "edr_hosts_with_agent", "Хостов с агентом EDR", ["company", "host_type"]
            )
            hosts_online = gauge(
                "edr_hosts_agent_online", "Хостов с агентом на связи", ["company", "host_type"]
            )
            hosts_excluded = gauge(
                "edr_hosts_excluded", "Хостов исключено правилами exclusions", ["company"]
            )
            # Агенты, не сматченные ни с одним хостом. Единственный сигнал о том,
            # что источник инвентаря отсутствует целиком: покрытие при этом
            # остаётся красивым — считается по тем хостам, которые видно.
            # Число тенантное: у компаний общего тенанта оно одинаковое.
            agents_without_inventory = gauge(
                "edr_agents_without_inventory",
                "Агентов EDR без хоста в инвентаре (по тенанту)",
                ["company"],
            )
            # Managed-ноды (БД, kubernetes) агент принять не могут и в покрытие
            # не входят. Показываем их числом, а не прячем: молча выпавший из
            # знаменателя хост — это то, чего в метрике покрытия быть не должно.
            hosts_managed = gauge(
                "edr_hosts_managed",
                "Хостов исключено как managed-сервис (агент невозможен)",
                ["company", "managed_type"],
            )
            managed_rows = frame[frame[merge3.MANAGED_COL] != ""]
            for (company, kind), count in (
                managed_rows.groupby([merge3.COMPANY_COL, merge3.MANAGED_COL]).size().items()
            ):
                hosts_managed.labels(company, kind).set(count)
            # Проценты не экспортируем: считаются в Grafana из счётчиков, иначе
            # агрегат по нескольким компаниям пришлось бы усреднять неверно.
            for company, m in overall["COMPANIES"].items():
                for host_type, key in (("server", "SERVERS"), ("workstation", "WORKSTATIONS")):
                    hosts_total.labels(company, host_type).set(m[key]["VM_TOTAL"])
                    hosts_with_agent.labels(company, host_type).set(m[key]["EDR_VM_TOTAL"])
                    hosts_online.labels(company, host_type).set(m[key]["EDR_VM_ONLINE"])
                hosts_excluded.labels(company).set(m.get("EXCLUDED", 0))
                agents_without_inventory.labels(company).set(
                    m.get("AGENTS_WITHOUT_INVENTORY", 0)
                )

            installed = gauge(
                "edr_host_agent_installed",
                "На хосте найден агент EDR",
                ["company", "hostname", "host_type"],
            )
            online = gauge(
                "edr_host_agent_online",
                "Агент EDR на хосте на связи",
                ["company", "hostname", "host_type"],
            )
            last_seen = gauge(
                "edr_host_agent_last_seen_seconds",
                "Unix-время последней связи агента (для окна «молчит»; только хосты с агентом)",
                ["company", "hostname", "host_type"],
            )
            # Только хосты из пула: исключённые не должны попадать ни в списки,
            # ни в счётчики, иначе дашборд разойдётся с агрегатами.
            for row in frame[frame["in_pool"]].itertuples():
                labels = (row.company, row.hostname, row.source_type)
                installed.labels(*labels).set(int(bool(row.has_edr)))
                online.labels(*labels).set(int(bool(row.edr_online)))
                ls = getattr(row, "edr_last_seen", float("nan"))
                if ls == ls:  # не NaN — агент есть и у него известна дата связи
                    last_seen.labels(*labels).set(float(ls))

            gauge(
                "edr_collection_timestamp_seconds", "Unix-время последнего успешного сбора"
            ).set(time.time())

        body = generate_latest(registry)
        with self._lock:
            self._body = body
            self.collected_at = time.time()

    def body(self):
        with self._lock:
            return self._body


def _load_module(name, filename):
    path = Path(__file__).resolve().parent / filename
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def run_collectors() -> dict:
    """Прогнать сборщики источников перед merge. Возвращает {section: failed}.

    Каждый сборщик — в своей секции: падение одного (протухший токен, недоступный
    DC) не роняет остальные, остаётся прошлый CSV этого источника, а флаг ошибки
    поднимается в edr_collect_errors{section}. Источник без конфига пропускается —
    это не ошибка (например SberCloud, пока не завезли креды).
    """
    errors = {}
    if not COLLECT_SOURCES:
        return errors
    for section, filename, config_name in COLLECTORS:
        configured = (CONFIG_DIR / config_name).exists()
        if section == "vkcloud" and not configured:
            configured = bool(os.environ.get("VKC_USERNAME"))
        if not configured:
            continue
        try:
            log.info("сбор источника: %s", section)
            _load_module(section, filename).main()
            errors[section] = False
        except Exception:
            log.exception("сбор источника %s упал", section)
            errors[section] = True
    return errors


def collect(snapshot):
    """Полный прогон пайплайна с записью артефактов и обновлением снапшота."""
    started = time.time()
    errors = run_collectors()

    try:
        frame, overall = merge3.build_report()
        errors["merge"] = False
    except Exception:
        log.exception("сбор упал")
        errors["merge"] = True
        snapshot.render(None, {}, time.time() - started, errors)
        return

    duration = time.time() - started
    snapshot.render(frame, overall, duration, errors)

    if not frame.empty:
        try:
            frame.to_csv(merge3.OUTPUT_CSV, index=False, encoding="utf-8")
        except Exception:
            log.exception("не смог записать %s", merge3.OUTPUT_CSV)
        log.info(
            "сбор за %.1fс: хостов %d, с агентом %d (%.1f%%)",
            duration,
            overall["VM_TOTAL"],
            overall["EDR_VM_TOTAL"],
            overall["EDR_COVERAGE_PCT"],
        )


def collect_loop(snapshot):
    """Пересчёт по расписанию; в ручном режиме — ещё и при подмене CSV.

    ВАЖНО: следить за mtime исходных CSV имеет смысл только когда сборщики
    ВЫКЛЮЧЕНЫ (ручная заливка файлов). Если сборщики включены, они сами пишут
    эти файлы — и слежка приняла бы собственную запись за изменение, устроив
    бесконечный пересбор раз в WATCH_INTERVAL (и долбёжку LDAP/облаков/EDR vendor).
    """
    last_mtimes = source_files()
    last_run = 0.0
    while True:
        due = time.time() - last_run >= COLLECT_INTERVAL
        changed = False
        if not COLLECT_SOURCES:
            mtimes = source_files()
            changed = mtimes != last_mtimes
            last_mtimes = mtimes
        if due or changed:
            if changed and not due:
                log.info("исходные файлы изменились — пересчитываю")
            collect(snapshot)
            last_run = time.time()
        time.sleep(WATCH_INTERVAL)


class Handler(BaseHTTPRequestHandler):
    snapshot = None

    def log_message(self, fmt, *args):  # шумный дефолтный лог — в debug
        log.debug(fmt, *args)

    def _respond(self, code, body, content_type="text/plain; charset=utf-8"):
        if isinstance(body, str):
            body = body.encode()
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/-/healthy":
            return self._respond(200, "ok\n")
        if self.path != "/metrics":
            return self._respond(404, "use /metrics\n")
        body = self.snapshot.body()
        if not body:
            # Первый сбор ещё идёт: 503 честнее пустого ответа — vmagent
            # пометит таргет down вместо того, чтобы записать нули.
            return self._respond(503, "collecting, no snapshot yet\n")
        self._respond(200, body, CONTENT_TYPE_LATEST)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--oneshot", action="store_true", help="посчитать один раз, вывести метрики и выйти"
    )
    args = parser.parse_args()

    logging.basicConfig(
        level=os.environ.get("LOG_LEVEL", "INFO"),
        format="%(asctime)s %(levelname)s %(message)s",
        stream=sys.stderr,
    )

    snapshot = Snapshot()

    if args.oneshot:
        collect(snapshot)
        sys.stdout.write(snapshot.body().decode())
        return

    threading.Thread(target=collect_loop, args=(snapshot,), daemon=True).start()

    Handler.snapshot = snapshot
    host, _, port = LISTEN.rpartition(":")
    server = ThreadingHTTPServer((host, int(port)), Handler)
    log.info("слушаю %s, данные из %s, пересчёт раз в %dс",
             LISTEN, merge3.DATA_DIR.resolve(), COLLECT_INTERVAL)
    server.serve_forever()


if __name__ == "__main__":
    main()
