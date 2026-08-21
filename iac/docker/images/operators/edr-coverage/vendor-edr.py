"""Выгрузка агентов EDR в {company}_edr.csv.

Заменяет ручной экспорт: раньше *_edr.csv клали руками. API — OAuth2 password +
курсорная пагинация /api/v1/agents/list-v2 (см. swagger tenant'а).

Несколько компаний часто сидят на одном tenant с одними кредами — тянем список
раз на (url, username) и пишем одинаковый CSV для каждой компании группы, а не
дёргаем API по разу на компанию.

Конфиг: EDR_CONFIG_DIR/edr_config.json (по умолчанию текущий каталог):
  {"<company>": {"username": "", "password": "",
                 "url": "https://<tenant>.edr.example.com:8080", "use_proxy": false}}

Прокси (use_proxy=true) берётся из EDR_PROXY_URL — в отличие от старого скрипта
адрес не захардкожен. ВМ мониторинга ходит в EDR vendor напрямую, там use_proxy=false.
"""

import collections
import json
import logging
import os
import re
import sys
from pathlib import Path

import pandas as pd
import requests
import urllib3
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

log = logging.getLogger("vendor_edr")

DATA_DIR = Path(os.environ.get("EDR_DATA_DIR", "."))
CONFIG_DIR = Path(os.environ.get("EDR_CONFIG_DIR", "."))
CONFIG_PATH = CONFIG_DIR / "edr_config.json"
REQUEST_TIMEOUT = int(os.environ.get("EDR_API_TIMEOUT", "60"))
PROXY_URL = os.environ.get("EDR_PROXY_URL", "")

# Локальные домены, которые надо срезать с hostname, чтобы имена совпадали с
# инвентарём облаков/AD. Панель сенсоров иногда отдаёт FQDN.
LOCAL_DOMAIN_SUFFIXES = [
    s.strip().lower()
    for s in os.environ.get(
        "EDR_STRIP_SUFFIXES",
        ".ru-central1.internal,.novalocal,.example.com",
    ).split(",")
    if s.strip()
]

# Колонки итогового CSV (то, что читает merge3 и метрика свежести). Порядок и
# нижний регистр — как в исторических выгрузках, чтобы ничего не поехало.
OUTPUT_COLUMNS = [
    "id", "name", "displayname", "domain", "os", "osname", "osversion", "sourceip",
    "isauthorized", "version", "isonline", "versionstatus", "lastseenat",
    "registeredat", "lastuser", "inv_hostname", "mac",
]

# Обогащение записей данными из /agents/{id}: список list-v2 их не отдаёт.
#   disputed (по умолчанию) — только спорные записи, чьё имя не идентифицирует
#     машину: дубли имён и обрезанные имена. Их около 49 из 482, обход занимает
#     секунды. Для них inventory.hostname восстанавливает настоящее имя: агенты
#     с именем '192' оказываются m-proj-c-00026 и m-proj-c-00012.
#   all — по всем агентам (~482 запроса, порядка 30 секунд): нужно, если MAC
#     используется как ключ сопоставления.
#   off — не ходить в detail вовсе.
ENRICH_MODE = os.environ.get("EDR_ENRICH", "disputed").strip().lower()

# Имя, состоящее только из цифр и точек, машину не идентифицирует: macOS кладёт
# в короткое имя часть до первой точки, и хост 192.168.1.11 приезжает как '192'.
NUMERIC_NAME = re.compile(r"^[\d.]+$")
# Поля агента из API (camelCase) -> колонка CSV (lower). Отсутствующие в ответе
# заполняются пустыми.
API_TO_CSV = {
    "id": "id", "name": "name", "displayName": "displayname",
    "domain": "domain", "os": "os",
    "osName": "osname", "osVersion": "osversion", "sourceIP": "sourceip",
    "isAuthorized": "isauthorized", "version": "version", "isOnline": "isonline",
    "versionStatus": "versionstatus", "lastSeenAt": "lastseenat",
    # момент регистрации агента: у переустановленного он свежий, а у старой
    # записи того же хоста — прежний, по нему видно, что это перерегистрация.
    # NB: приходит заполненным только у 74 агентов из 482, так что как признак
    # «мёртвой записи» он не годится — нечем измерять.
    "registeredAt": "registeredat", "lastUser": "lastuser",
}

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


def load_config() -> dict:
    if not CONFIG_PATH.exists():
        log.error("нет конфига %s", CONFIG_PATH)
        sys.exit(1)
    return json.loads(CONFIG_PATH.read_text(encoding="utf-8"))


def make_session(use_proxy: bool) -> requests.Session:
    session = requests.Session()
    # Панель сенсоров изредка рвёт TLS-хендшейк (UNEXPECTED_EOF) — переживаем
    # ретраями с backoff, а не роняем всю секцию vendor.
    retry = Retry(total=4, backoff_factor=1.0,
                  status_forcelist=[429, 500, 502, 503, 504],
                  allowed_methods=["GET", "POST"])
    adapter = HTTPAdapter(max_retries=retry)
    session.mount("https://", adapter)
    session.mount("http://", adapter)
    if use_proxy:
        if not PROXY_URL:
            log.warning("use_proxy=true, но EDR_PROXY_URL не задан — иду напрямую")
        else:
            session.proxies = {"http": PROXY_URL, "https": PROXY_URL}
    return session


def get_token(session: requests.Session, url: str, username: str, password: str) -> str:
    resp = session.post(
        f"{url}/api/v1/oauth2/token",
        headers={"Accept": "application/json", "User-Agent": "sec-stack-edr-coverage/1.0"},
        data={"grant_type": "password", "username": username, "password": password},
        verify=False,
        timeout=REQUEST_TIMEOUT,
    )
    resp.raise_for_status()
    return resp.json()["access_token"]


def fetch_agents(session: requests.Session, url: str, token: str) -> list[dict]:
    """Все агенты tenant'а через курсорную пагинацию list-v2."""
    headers = {"Authorization": f"Bearer {token}"}
    agents, cursor = [], None
    while True:
        page_filter = {"sort": {"by": "name", "order": "ASC"}, "pagination": {"first": 1000}}
        if cursor:
            page_filter["pagination"]["after"] = cursor
        resp = session.post(
            f"{url}/api/v1/agents/list-v2",
            files={"filter": (None, json.dumps(page_filter))},
            headers=headers,
            verify=False,
            timeout=REQUEST_TIMEOUT,
        )
        resp.raise_for_status()
        data = resp.json()
        agents.extend(data.get("items") or [])
        page = data.get("pageInfo") or {}
        if not page.get("hasNextPage"):
            break
        cursor = page.get("endCursor")
        if not cursor:
            break
    return agents


def _match_key(name) -> str:
    """Ключ сравнения имён — тот же, что в merge3._norm_host (upper, '_' -> '-')."""
    return str(name or "").strip().upper().replace("_", "-")


def disputed_agents(agents: list[dict]) -> list[dict]:
    """
    Записи, чьё имя не идентифицирует машину: имя совпадает с именем другого
    агента (переустановка или коллизия) либо состоит только из цифр и точек.
    Ровно эти записи в merge3 схлопывает дедуп или отбраковывает матчинг.
    """
    counts = collections.Counter(_match_key(a.get("name")) for a in agents)
    return [
        a for a in agents
        if counts[_match_key(a.get("name"))] > 1 or NUMERIC_NAME.match(_match_key(a.get("name")))
    ]


def fetch_agent_detail(session: requests.Session, url: str, token: str, agent_id: str) -> dict:
    """Карточка агента: inventory (hostname, сетевые интерфейсы) в list-v2 не приходит."""
    resp = session.get(
        f"{url}/api/v1/agents/{agent_id}",
        headers={"Authorization": f"Bearer {token}"},
        verify=False,
        timeout=REQUEST_TIMEOUT,
    )
    resp.raise_for_status()
    return resp.json()


def enrich_agents(session: requests.Session, url: str, token: str, agents: list[dict]) -> None:
    """
    Дописать в записи агентов inventory.hostname и MAC-адреса из /agents/{id}.

    Ходим не по всем агентам, а по спорным (см. ENRICH_MODE): их единицы, а
    именно им нечем верить. Сбой по одному агенту не должен ронять выгрузку —
    поле останется пустым, это ровно то же состояние, что и без обогащения.
    """
    if ENRICH_MODE == "off":
        return
    targets = agents if ENRICH_MODE == "all" else disputed_agents(agents)
    if not targets:
        return

    failed = 0
    for agent in targets:
        try:
            inventory = fetch_agent_detail(session, url, token, agent["id"]).get("inventory") or {}
        except Exception as exc:
            failed += 1
            log.debug("detail для агента %s не получен: %s", agent.get("id"), exc)
            continue
        agent["invHostname"] = (inventory.get("hostname") or "").strip()
        macs = {
            str(iface.get("mac")).strip().lower()
            for iface in (inventory.get("networkInterfaces") or [])
            if iface.get("mac")
        }
        agent["macs"] = ",".join(sorted(macs))

    recovered = sum(
        1 for a in targets
        if a.get("invHostname") and _match_key(a["invHostname"]) != _match_key(a.get("name"))
    )
    log.info("обогащено записей: %d из %d (режим %s), имя восстановлено у %d, без ответа %d",
             len(targets) - failed, len(agents), ENRICH_MODE, recovered, failed)


def normalize_name(name, comment) -> str:
    """Имя хоста: comment важнее name (тех.поддержка EDR vendor правит кривые FQDN),
    срезаем локальный домен, в верхний регистр.

    NB (проверено на живом API 2026-08-12): в ответе /agents/list-v2 поля comment
    нет вовсе — непустой comment у 0 из 482 агентов, оно живёт только в
    /agents/{id}. Ветка с comment остаётся на случай, если панель начнёт его
    отдавать, но фактическое имя сейчас всегда приходит из name. Само API уже
    может отдать имя обрезанным: macOS кладёт в короткое имя часть до первой
    точки, поэтому хост с сетевым именем 192.168.1.11 приезжает как '192'.
    Полное имя лежит в displayName — оно выгружается отдельной колонкой.
    """
    comment = str(comment or "").strip()
    base = comment if comment and comment.lower() not in ("nan", "none") else str(name or "").strip()
    low = base.lower()
    for suffix in LOCAL_DOMAIN_SUFFIXES:
        if low.endswith(suffix):
            base = base[: -len(suffix)]
            break
    return base.upper()


def agents_to_df(agents: list[dict]) -> pd.DataFrame:
    rows = []
    for a in agents:
        row = {csv_col: a.get(api_key, "") for api_key, csv_col in API_TO_CSV.items()}
        row["name"] = normalize_name(a.get("name"), a.get("comment"))
        # заполнены только у обогащённых записей (см. enrich_agents)
        row["inv_hostname"] = a.get("invHostname", "")
        row["mac"] = a.get("macs", "")
        rows.append(row)
    df = pd.DataFrame(rows, columns=OUTPUT_COLUMNS)
    # метки времени к виду YYYY-MM-DD HH:MM:SS (как в исторических выгрузках)
    for col in ("lastseenat", "registeredat"):
        ts = pd.to_datetime(df[col], errors="coerce", utc=True)
        df[col] = ts.dt.tz_localize(None).dt.strftime("%Y-%m-%d %H:%M:%S")
    return df


def main():
    logging.basicConfig(
        level=os.environ.get("LOG_LEVEL", "INFO"),
        format="%(asctime)s %(levelname)s %(message)s",
        stream=sys.stderr,
    )
    config = load_config()

    # Группируем компании по (url, username): один tenant — один запрос к API.
    groups: dict[tuple, list[str]] = {}
    creds: dict[tuple, dict] = {}
    for company, cfg in config.items():
        key = (cfg["url"], cfg["username"])
        groups.setdefault(key, []).append(company)
        creds[key] = cfg

    failures = 0
    for (url, username), companies in groups.items():
        cfg = creds[(url, username)]
        try:
            session = make_session(cfg.get("use_proxy", False))
            token = get_token(session, url, username, cfg["password"])
            agents = fetch_agents(session, url, token)
            enrich_agents(session, url, token, agents)
            df = agents_to_df(agents)
            for company in companies:
                out = DATA_DIR / f"{company}_edr.csv"
                df.to_csv(out, index=False, encoding="utf-8")
            log.info("tenant %s: агентов %d -> %s",
                     url.split("//")[-1].split(".")[0], len(df),
                     ", ".join(f"{c}_edr.csv" for c in companies))
        except Exception:
            failures += 1
            log.exception("tenant %s (%s): выгрузка не удалась",
                          url, ", ".join(companies))

    if failures:
        sys.exit(1)


if __name__ == "__main__":
    main()
