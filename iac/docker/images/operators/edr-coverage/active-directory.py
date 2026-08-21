"""
Export domain hosts from Active Directory via LDAP/LDAPS.
Reads ad_config.yaml and writes {company}-ad.csv for each company entry.
Output is automatically picked up by merge3.py for EDR coverage analysis.

Выгружаются и рабочие места, и серверы: OU перечисляются в `workstation_ous` и
`server_ous`, тип попадает в колонку source_type. Отдельного атрибута «это
сервер» в каталоге нет (проверено 2026-08-16: у рядового сервера и у ноутбука
одинаковый userAccountControl=0x1000, SPN тоже совпадают), поэтому тип задаётся
организационно — списком OU, а `operatingSystem` служит проверкой. Железно из
каталога определяются только контроллеры домена: primaryGroupID=516.

Каждый OU читается ровно один раз, даже если его указали несколько компаний, а
хосты раздаются по компаниям после чтения — так хост, не подошедший ни под чьи
паттерны, попадает к `default_company`, а не пропадает молча.
"""
import fnmatch
import logging
import os
import ssl
import sys
from pathlib import Path

import pandas as pd
import yaml
from ldap3 import SUBTREE, Connection, Server, Tls
from ldap3.core.exceptions import LDAPException

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    stream=sys.stdout,
)
logger = logging.getLogger(__name__)

# Конфиг — из EDR_CONFIG_DIR (в контейнере это read-only каталог с секретами,
# который рендерит ansible из SOPS); результат — в EDR_DATA_DIR. По умолчанию
# оба указывают на текущий каталог — для ручного прогона с ноутбука.
CONFIG_DIR = Path(os.environ.get("EDR_CONFIG_DIR", "."))
DATA_DIR = Path(os.environ.get("EDR_DATA_DIR", "."))
CONFIG_PATH = CONFIG_DIR / "ad_config.yaml"

# userAccountControl bit 1 (0x2) — account is disabled
UAC_DISABLED_BIT = 0x2
# Контроллеры домена: единственный тип, который каталог отдаёт однозначно
DC_PRIMARY_GROUP = 516

# Признак типа по operatingSystem. Используется, когда OU помечен source_type: auto,
# и для сверки объявленного типа с фактическим — расхождение пишем в лог.
OS_MATCHERS = {
    # клиентская Windows: Server в названии её исключает
    "windows": lambda os_name: os_name.lower().startswith("windows") and "server" not in os_name.lower(),
    "macos":   lambda os_name: os_name.lower().startswith("macos"),
    # подстрока, а не префикс: часть Linux-машин рапортует 'pc-linux-gnu'
    "linux":   lambda os_name: "linux" in os_name.lower(),
    "server":  lambda os_name: "server" in os_name.lower() or "linux" in os_name.lower(),
    # любая непустая ОС: у сервисных учёток она пустая
    "any":     lambda os_name: bool(os_name.strip()),
    "all":     lambda os_name: True,
}

# AD computer object attributes to request
COMPUTER_ATTRS = [
    "cn",
    "dNSHostName",
    "operatingSystem",
    "operatingSystemVersion",
    "userAccountControl",
    "primaryGroupID",
    "distinguishedName",
    "whenCreated",
    "lastLogonTimestamp",
]

# gMSA наследуются от класса computer и иначе попадают в выдачу как машины
BASE_FILTER = "(&(objectClass=computer)(!(objectClass=msDS-GroupManagedServiceAccount)){extra})"


def load_config(config_path: str = CONFIG_PATH) -> list[dict]:
    path = Path(config_path)
    if not path.exists():
        raise FileNotFoundError(f"Config file not found: {path.resolve()}")
    with path.open("r", encoding="utf-8") as f:
        data = yaml.safe_load(f)
    return data["companies"]


def build_ldap_filter(enabled_only: bool) -> str:
    """Фильтр поиска. Отбор по ОС делается после чтения — один OU читается один
    раз на всех, а os_filter у компаний разный."""
    extra = "(!(userAccountControl:1.2.840.113556.1.4.803:=2))" if enabled_only else ""
    return BASE_FILTER.format(extra=extra)


def connect(server_url: str, bind_dn: str, password: str, tls_insecure: bool) -> Connection:
    tls = Tls(validate=ssl.CERT_NONE) if tls_insecure else None
    server = Server(server_url, use_ssl=server_url.lower().startswith("ldaps"),
                    tls=tls, get_info=None)
    return Connection(server, user=bind_dn, password=password, auto_bind=True,
                      read_only=True, raise_exceptions=True)


def search_ou(conn: Connection, base: str, ldap_filter: str) -> list:
    entries, cookie = [], None
    while True:
        conn.search(base, ldap_filter, SUBTREE, attributes=COMPUTER_ATTRS,
                    paged_size=500, paged_cookie=cookie)
        entries.extend(conn.entries)
        cookie = conn.result.get("controls", {}).get(
            "1.2.840.113556.1.4.319", {}).get("value", {}).get("cookie")
        if not cookie:
            return entries


def entry_to_dict(entry) -> dict:
    def val(attr):
        v = getattr(entry, attr, None)
        return v.value if v is not None else None

    uac      = val("userAccountControl") or 0
    dns_name = val("dNSHostName") or ""
    cn       = val("cn") or ""
    # Имя из dNSHostName: у Linux-серверов cn обрезан до 15 символов (NetBIOS),
    # и 'PROJ-B-DEMO-CERTM' не сматчился бы с 'proj-b-demo-certmanager' из облака.
    fqdn       = (dns_name or cn).lower()
    short_name = fqdn.split(".")[0]

    return {
        "hostname":   short_name,
        "fqdn":       fqdn,
        "sourceip":   "",  # AD doesn't store IP; EDR matching is done by hostname
        "os":         val("operatingSystem") or "",
        "os_version": val("operatingSystemVersion") or "",
        "dn":         val("distinguishedName") or "",
        "enabled":    not bool(int(uac) & UAC_DISABLED_BIT),
        "is_dc":      int(val("primaryGroupID") or 0) == DC_PRIMARY_GROUP,
    }


# ---------------------------------------------------------------------------
# Раздача хостов по компаниям
# ---------------------------------------------------------------------------

def ou_entries(company: dict) -> list[tuple[str, str]]:
    """
    OU компании как (dn, объявленный тип). Элемент списка — либо строка с DN,
    либо {dn: ..., source_type: server|workstation|auto}.
    """
    result = []
    for key, default_type in (("workstation_ous", "workstation"), ("server_ous", "server")):
        for item in company.get(key) or []:
            if isinstance(item, dict):
                result.append((item["dn"], item.get("source_type", default_type)))
            else:
                result.append((item, default_type))
    return result


def host_type(host: dict, declared: str) -> str:
    """
    Тип хоста: объявленный в конфиге, кроме контроллеров домена — они серверы
    всегда. 'auto' выводит тип из operatingSystem.
    """
    if host["is_dc"]:
        return "server"
    if declared != "auto":
        return declared
    return "server" if OS_MATCHERS["server"](host["os"]) else "workstation"


def os_allowed(host: dict, source_type: str, company: dict) -> bool:
    """Проходит ли хост фильтр по ОС: для АРМ — os_filter компании, для серверов
    любая непустая ОС (иначе в выгрузку попадут объекты без ОС)."""
    key = company.get("os_filter", "windows") if source_type == "workstation" \
        else company.get("server_os_filter", "any")
    return OS_MATCHERS.get(key, OS_MATCHERS["all"])(host["os"])


def _matches_any(hostname_upper: str, patterns_upper: list[str]) -> bool:
    return any(fnmatch.fnmatch(hostname_upper, p) for p in patterns_upper)


CLAIMS_ALL = "all"


def patterns_of(company: dict, source_type: str) -> list[str] | str:
    """
    Паттерны компании для этого типа хостов: список либо CLAIMS_ALL.

    `all` — явная пометка «забираю всё, что осталось в моих OU». Пустой список
    означает то же самое, но неявно, поэтому о нём предупреждаем: именно из-за
    молчаливого «пусто = всё» project-a однажды выгреб 30 серверов project-b.
    """
    key = "hostname_patterns" if source_type == "workstation" else "server_hostname_patterns"
    value = company.get(key)
    if isinstance(value, str):
        return CLAIMS_ALL if value.strip().lower() == CLAIMS_ALL else [value]
    return list(value) if value else CLAIMS_ALL


def company_claims(company: dict, host: dict, source_type: str) -> bool:
    """Забирает ли компания этот хост (с учётом exclude-паттернов)."""
    name = host["hostname"].upper()
    include = patterns_of(company, source_type)
    exclude = [p.upper() for p in (company.get("hostname_exclude_patterns") or [])]
    if include != CLAIMS_ALL and not _matches_any(name, [p.upper() for p in include]):
        return False
    return not _matches_any(name, exclude)


def _deduplicate_nested_ous(hosts_by_ou: dict[str, list[dict]]) -> dict[str, list[dict]]:
    """
    Один хост — один OU: самый специфичный из тех, что его вернули.

    OU вкладываются друг в друга (`OU=MacOS,OU=Laptops,OU=Assets` внутри
    `OU=Laptops,OU=Assets`), а поиск идёт SUBTREE, поэтому одна и та же машина
    приходит под двумя ключами. Раздавая их независимо, мы отдаём хост дважды:
    по `OU=MacOS` его забирает project-e паттерном `m-*`, а по `OU=Laptops` он не
    подходит никому и уходит к `default_company`. Так `m-user-c` оказался и в
    project-a, и в project-e, а в покрытии — дважды.

    Самый глубокий OU выбран потому, что это самое точное указание админа: если
    он отдельно перечислил вложенный OU, значит имел в виду именно его.
    """
    best: dict[str, tuple[str, dict]] = {}
    for ou, hosts in hosts_by_ou.items():
        for host in hosts:
            key = host["dn"].upper()
            if key not in best or len(ou) > len(best[key][0]):
                best[key] = (ou, host)
    result: dict[str, list[dict]] = {ou: [] for ou in hosts_by_ou}
    for ou, host in best.values():
        result[ou].append(host)
    return result


def assign_hosts(hosts_by_ou: dict[str, list[dict]],
                 companies: list[dict]) -> tuple[dict[str, list[dict]], list[dict]]:
    """
    Раздать хосты по компаниям. Возвращает (компания -> строки, нераспределённые).

    Претендуют только компании, у которых этот OU указан в конфиге. Если никто не
    забрал — хост уходит к компании с `default_company: true`, а если и её нет,
    попадает в список нераспределённых: молча пропасть он не должен, это уже
    стоило нам четырёх компаний, полгода не попадавших в метрики.
    """
    claimed: dict[str, list[dict]] = {c["name"]: [] for c in companies}
    unassigned: list[dict] = []
    default = next((c for c in companies if c.get("default_company")), None)

    for ou, hosts in _deduplicate_nested_ous(hosts_by_ou).items():
        owners = [(c, declared) for c in companies
                  for dn, declared in ou_entries(c) if dn.upper() == ou.upper()]
        for host in hosts:
            row, taken = None, None
            # Сначала компании с явными паттернами, потом «всеядные»: порядок в
            # конфиге ничего не решает. Иначе компания без паттернов, стоящая
            # первой, выгребает из общего OU чужие хосты — так project-a забрал
            # 30 серверов project-b, и суммарные метрики этого не показали.
            for specific_first in (True, False):
                for company, declared in owners:
                    is_specific = patterns_of(company, host_type(host, declared)) != CLAIMS_ALL
                    if is_specific != specific_first:
                        continue
                    source_type = host_type(host, declared)
                    if not os_allowed(host, source_type, company):
                        continue
                    if company_claims(company, host, source_type):
                        taken, row = company, dict(host, source_type=source_type)
                        break
                if taken is not None:
                    break
            if taken is None and default is not None:
                declared = next((d for c, d in owners if c["name"] == default["name"]), None)
                if declared is not None:
                    source_type = host_type(host, declared)
                    if os_allowed(host, source_type, default):
                        taken, row = default, dict(host, source_type=source_type)
            if taken is None:
                unassigned.append(host)
            else:
                claimed[taken["name"]].append(row)
    return claimed, unassigned


def validate_config(companies: list[dict]) -> list[str]:
    """
    Проверки, которые ловят неоднозначный конфиг до того, как он тихо разъедется.

    Ошибка ровно одна: два «всеядных» претендента на один OU и один тип хостов.
    Кому достанется хост в этом случае, из конфига не следует никак, и раньше
    решал порядок строк. Остальное — предупреждения: неявное «пусто = всё»
    работает, но должно быть написано словом (`claims`-паттерны: `all`).
    """
    problems: list[str] = []
    for source_type, ou_key in (("workstation", "workstation_ous"), ("server", "server_ous")):
        by_ou: dict[str, list[dict]] = {}
        for company in companies:
            for dn, declared in ou_entries(company):
                if declared == "auto" or (declared == source_type) or \
                        (ou_key in company and dn in [
                            item["dn"] if isinstance(item, dict) else item
                            for item in company.get(ou_key) or []]):
                    by_ou.setdefault(dn.upper(), []).append(company)
        for ou, owners in by_ou.items():
            greedy = [c["name"] for c in owners
                      if patterns_of(c, source_type) == CLAIMS_ALL
                      and not (c.get("hostname_exclude_patterns") or [])]
            if len(greedy) > 1:
                problems.append(
                    f"OU {ou}: несколько компаний забирают всё ({', '.join(greedy)}) "
                    f"для типа '{source_type}'. Задайте паттерны или exclude — из конфига "
                    f"не следует, чей это хост"
                )
    for company in companies:
        for source_type, ou_key in (("workstation", "workstation_ous"), ("server", "server_ous")):
            if company.get(ou_key) and patterns_of(company, source_type) == CLAIMS_ALL \
                    and not isinstance(company.get(
                        "hostname_patterns" if source_type == "workstation"
                        else "server_hostname_patterns"), str):
                logger.warning(
                    "Company '%s': паттерны для '%s' не заданы — забирает всё из своих OU. "
                    "Напишите это явно: %s: all",
                    company["name"], source_type,
                    "hostname_patterns" if source_type == "workstation" else "server_hostname_patterns",
                )
    return problems


def check_empty_result(company: dict, rows: list[dict]) -> None:
    """
    Компания объявила OU, но не получила оттуда ни одного хоста.

    Это и есть сигнал, которого не хватало: у project-b с пятью серверными OU в логе
    стояло `saved 14 hosts {'workstation': 14}` — ноль серверов и ни одного
    предупреждения, при том что суммарное покрытие выглядело здоровым.
    """
    kinds = {row["source_type"] for row in rows}
    for source_type, ou_key in (("workstation", "workstation_ous"), ("server", "server_ous")):
        if company.get(ou_key) and source_type not in kinds:
            logger.warning(
                "Company '%s': задано %d %s, но получено 0 хостов типа '%s' — "
                "проверить паттерны: их мог перехватить кто-то другой",
                company["name"], len(company[ou_key]), ou_key, source_type,
            )


def check_declared_type(rows: list[dict], company: str) -> None:
    """Сверка типа из конфига с фактической ОС — расхождение не исправляем молча,
    а показываем: OU это административное решение, ОС — факт от машины."""
    for row in rows:
        if not row["os"]:
            continue
        looks_server = OS_MATCHERS["server"](row["os"])
        if looks_server and row["source_type"] == "workstation":
            logger.warning("  %s: %s помечен как АРМ, а ОС серверная (%s)",
                           company, row["hostname"], row["os"])
        elif not looks_server and row["source_type"] == "server" and not row["is_dc"]:
            logger.warning("  %s: %s помечен как сервер, а ОС клиентская (%s)",
                           company, row["hostname"], row["os"])


def main() -> None:
    companies = load_config(CONFIG_PATH)
    if not companies:
        logger.error("В конфиге нет компаний")
        sys.exit(1)

    problems = validate_config(companies)
    for problem in problems:
        logger.error("Конфиг: %s", problem)
    if problems:
        # Лучше не выгрузить ничего, чем выгрузить неправильно: прошлые CSV
        # останутся на месте, а экспортер отметит секцию как упавшую.
        sys.exit(1)

    # Один OU читается один раз, даже если его указали несколько компаний:
    # раньше общий OU=Laptops перечитывался по разу на компанию.
    wanted: dict[str, dict] = {}
    for company in companies:
        for dn, _ in ou_entries(company):
            wanted.setdefault(dn, company)

    first = companies[0]
    ldap_filter = build_ldap_filter(first.get("enabled_only", True))
    logger.info("Читаю %d OU, фильтр: %s", len(wanted), ldap_filter)
    try:
        conn = connect(first["server"], first["bind_dn"],
                       first.get("bind_password", ""), first.get("tls_insecure", False))
    except LDAPException as e:
        logger.error("LDAP connection error: %s", e)
        sys.exit(1)

    hosts_by_ou: dict[str, list[dict]] = {}
    try:
        for dn in wanted:
            entries = search_ou(conn, dn, ldap_filter)
            hosts = [entry_to_dict(e) for e in entries]
            hosts_by_ou[dn] = hosts
            logger.info("  %-70s %d", dn[:70], len(hosts))
    except LDAPException as e:
        logger.error("LDAP search error: %s", e)
        sys.exit(1)
    finally:
        conn.unbind()

    claimed, unassigned = assign_hosts(hosts_by_ou, companies)
    if unassigned:
        logger.warning(
            "Хостов не забрала ни одна компания: %d — они не попадут в метрики. "
            "Задайте паттерны или default_company. Примеры: %s",
            len(unassigned), ", ".join(h["hostname"] for h in unassigned[:10]),
        )

    for company in companies:
        rows = claimed[company["name"]]
        if not rows:
            logger.warning("Company '%s': no objects found", company["name"])
            check_empty_result(company, rows)
            continue
        check_declared_type(rows, company["name"])
        check_empty_result(company, rows)
        df = pd.DataFrame.from_records(rows).drop(columns=["is_dc"])
        before = len(df)
        df.drop_duplicates(subset=["hostname"], keep="first", inplace=True)
        if len(df) < before:
            logger.info("  %s: схлопнуто дублей hostname: %d", company["name"], before - len(df))
        df["company"] = company["name"]
        out_path = DATA_DIR / f"{company['name']}-ad.csv"
        df.to_csv(out_path, index=False, encoding="utf-8")
        counts = df["source_type"].value_counts().to_dict()
        logger.info("Company '%s': saved %d hosts %s → %s",
                    company["name"], len(df), counts, out_path)


if __name__ == "__main__":
    main()
