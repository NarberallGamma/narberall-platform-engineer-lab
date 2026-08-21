"""
EDR coverage analysis script.

Host files:  {company}-sbc-adv.csv, {company}-vkcloud.csv, {company}-ad.csv, ...
EDR files:   {company}_edr.csv
Exclusions:  exclusions.yaml  (optional)

Files with the '-ad' suffix are treated as workstations; all others as servers.
Metrics are calculated separately for servers and workstations.
Excluded hosts (appliances, network gear, etc.) keep excluded=True in the
output CSV but are not counted in any metrics.
"""
import collections
import fnmatch
import json
import logging
import os
import re
import sys
from pathlib import Path

import pandas as pd
import yaml

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    stream=sys.stdout,
)
logger = logging.getLogger(__name__)

# Каталог с исходными CSV и результатами. В контейнере экспортера — /data.
DATA_DIR = Path(os.environ.get("EDR_DATA_DIR", "."))
EXCLUSIONS_FILE = DATA_DIR / "exclusions.yaml"
# Соответствия «хост -> имя агента», которые из данных не выводятся: маки
# регистрируются в EDR под локальным именем, доменного нет ни в одном поле API.
ALIASES_FILE = DATA_DIR / "aliases.yaml"

# Column names
VM_HOSTNAME_COL = "hostname"
VM_OS_HOSTNAME_COL = "os_hostname"  # hostname внутри ОС (только SberCloud, см. ниже)
VM_SOURCEIP_COL = "sourceip"
VM_ENABLED_COL  = "enabled"    # present in -ad.csv
VM_DN_COL       = "dn"         # present in -ad.csv
EDR_NAME_COL    = "name"
EDR_ONLINE_COL  = "isonline"
# Имена колонок в *_edr.csv пишет API_TO_CSV в vendor-edr.py. Все в нижнем
# регистре. Расхождение здесь тихо ломает целый проход матчинга.
EDR_IP_COL      = "sourceip"   # optional IP column in EDR files
EDR_LASTSEEN_COL = "lastseenat"  # время последней связи агента (для окна «молчит»)
EDR_OSNAME_COL  = "osname"     # только для разбора дублей имён, в матчинге не участвует
EDR_LASTUSER_COL = "lastuser"  # только для подсказок к aliases.yaml
# Имя, под которым агент виден в панели EDR: обычно FQDN, а у обрезанных имён —
# единственный способ опознать машину ('192' в панели показан как 192.168.1.11).
EDR_DISPLAYNAME_COL = "displayname"
# Имя, которое агент рапортует о себе сам (inventory.hostname из /agents/{id}).
# Заполнено только у обогащённых записей — тех, чьё имя в списке не идентифицирует
# машину; для агента '192' здесь лежит настоящее доменное имя.
EDR_INV_HOSTNAME_COL = "inv_hostname"
COMPANY_COL     = "company"
SOURCE_TYPE_COL = "source_type"
EXCLUDED_COL    = "excluded"
# чем хост сматчен с агентом: hostname | alias | inv_hostname | os_hostname | ip | ''
MATCHED_BY_COL  = "matched_by"
IN_AD_COL       = "in_ad"       # хост есть в AD-выгрузке (доменный)
# Имя хоста занято машинами разных компаний — по имени такой хост не матчим:
# агент с этим именем один, а машин несколько, и он достался бы всем сразу
NAME_SHARED_COL = "name_shared"
# Тип managed-сервиса из выгрузки облака ('' — обычная ВМ). Агент на такие ноды
# поставить нельзя, поэтому в пул подсчёта они не входят, но из отчёта и метрик
# не пропадают — иначе занижение знаменателя было бы незаметным.
MANAGED_COL     = "managed"

TEMP_HOSTNAME_PREFIX = "CL1"   # temporary VMs to skip
AD_FILE_SUFFIX       = "-ad"   # marks a file as workstation source
EDR_FILE_SUFFIX      = "_edr"  # {company}_edr.csv — выгрузка агентов
# Суффиксы файлов инвентаря. Имя компании выделяем по ним, а не по префиксу:
# глоб '{company}*.csv' перетягивает чужие файлы у компаний с общим началом
# имени ('project-b' забрал бы файлы 'project-b-test'), и это никак не проявляется.
INVENTORY_SUFFIXES   = (AD_FILE_SUFFIX, "-vkcloud", "-sbc-adv")
# Пишет сам пайплайн — это не инвентарь и не потерянный источник
GENERATED_CSV        = ("edr_coverage_report.csv", "edr_report.csv")
OUTPUT_CSV           = DATA_DIR / "edr_coverage_report.csv"
OUTPUT_JSON          = DATA_DIR / "edr_metrics.json"


# ---------------------------------------------------------------------------
# Normalisation helpers
# ---------------------------------------------------------------------------

def _norm_host(values: pd.Series) -> pd.Series:
    """
    Ключ сопоставления имён хостов: регистр не значим, '_' — это '-'.

    Подчёркивание допустимо в имени ВМ в облаке, но не в hostname по RFC 1123:
    cloud-init заменяет его дефисом, и агент EDR регистрируется уже под изменённым
    именем ('ecs-corp-mfa_radius-az1-01' -> 'ecs-corp-mfa-radius-az1-01').
    Точки не трогаем — FQDN в именах не встречается ни в одной выгрузке
    (у AD полное имя лежит отдельной колонкой fqdn).

    Применять к обеим сторонам джойна, иначе правило разъедется.
    """
    return values.astype(str).str.strip().str.upper().str.replace("_", "-", regex=False)


def _split_ips(value) -> list[str]:
    """
    Адреса хоста из ячейки sourceip.

    Коллекторы пишут их строкой через запятую, но в исторических выгрузках VK
    Cloud лежит python-репр списка: "['10.0.2.19', '203.0.113.10']".
    """
    if value is None or (isinstance(value, float) and pd.isna(value)):
        return []
    text = str(value).strip().strip("[]")
    if not text or text.lower() == "nan":
        return []
    return [part.strip().strip("'\"") for part in text.split(",") if part.strip().strip("'\"")]


def _unique_ips(values: pd.Series) -> tuple[pd.Series, set[str]]:
    """
    Развернуть колонку с адресами в Series (индекс исходной строки -> один адрес)
    и вернуть вместе с множеством адресов, встречающихся ровно один раз.
    """
    exploded = values.map(_split_ips).explode().dropna()
    exploded = exploded[exploded != ""]
    counts = exploded.value_counts()
    return exploded, set(counts[counts == 1].index)


# ---------------------------------------------------------------------------
# Exclusions
# ---------------------------------------------------------------------------

def load_exclusions(path: Path = EXCLUSIONS_FILE) -> dict[str, dict]:
    """
    Load exclusions.yaml and return {company: rules_dict}.
    Each rules_dict has keys: patterns, hostnames, ips, ous.
    Company rules are merged with global rules (global + company-specific).
    '__global__' key holds rules applied when no company-specific entry exists.
    Returns empty dict if the file is not found.
    """
    if not path.exists():
        logger.info("No exclusions file (%s) — no exclusions applied", path)
        return {}

    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    g = data.get("global") or {}

    def _merge(base: dict, extra: dict) -> dict:
        return {
            key: (base.get(key) or []) + (extra.get(key) or [])
            for key in ("patterns", "hostnames", "ips", "ous")
        }

    result = {"__global__": _merge(g, {})}
    for company, c in (data.get("companies") or {}).items():
        result[company] = _merge(g, c or {})

    logger.info(
        "Loaded exclusions: %d company overrides + global rules",
        len(data.get("companies") or {}),
    )
    return result


def load_aliases(path: Path = ALIASES_FILE) -> dict[str, dict[str, str]]:
    """
    Ручные соответствия «хост -> имя агента»: {company: {хост: агент}}.

    Нужны там, где связь есть, но в данных её нет: доменный мак регистрируется
    в EDR под локальным именем ('MacBook-Air-admin.local', '192'), и доменного
    имени нет ни в одном поле API. Гадать по имени пользователя нельзя — второй
    ноутбук у того же человека молча испортил бы метрику, — поэтому решение
    принимает человек, а merge3 только подсказывает кандидатов в логе.

    Формат:
      companies:
        project-e:
          m-user-a: MAC
          m-user-b: "192"
    """
    if not path.exists():
        return {}
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    result = {
        company: {_norm_host(pd.Series([host]))[0]: _norm_host(pd.Series([agent]))[0]
                  for host, agent in (pairs or {}).items()}
        for company, pairs in (data.get("companies") or {}).items()
    }
    logger.info("Loaded aliases: %d соответствий в %d компаниях",
                sum(len(v) for v in result.values()), len(result))
    return result


def _exclusion_mask(df: pd.DataFrame, rules: dict) -> pd.Series:
    """
    Return a boolean Series — True where a host should be excluded.
    Checks (in order): exact hostnames, glob patterns, IPs, AD OUs.
    All hostname/pattern comparisons are case-insensitive.
    """
    mask = pd.Series(False, index=df.index)
    hostname = df[VM_HOSTNAME_COL].astype(str).str.strip().str.upper()

    # Exact hostname match
    if exact := {h.upper() for h in (rules.get("hostnames") or [])}:
        mask |= hostname.isin(exact)

    # Glob patterns — convert to a single regex for vectorised matching
    if patterns := [p.upper() for p in (rules.get("patterns") or [])]:
        regex = "|".join(fnmatch.translate(p) for p in patterns)
        mask |= hostname.str.match(regex)

    # IP match
    if ips := {str(x) for x in (rules.get("ips") or [])}:
        if VM_SOURCEIP_COL in df.columns:
            mask |= df[VM_SOURCEIP_COL].astype(str).isin(ips)

    # AD OU match — host is excluded if its DN contains any of the OU strings
    if ous := [ou.upper() for ou in (rules.get("ous") or [])]:
        if VM_DN_COL in df.columns:
            dn = df[VM_DN_COL].astype(str).str.upper()
            for ou in ous:
                mask |= dn.str.contains(ou, regex=False, na=False)

    return mask


def _apply_exclusions(df: pd.DataFrame, exclusions: dict, company: str) -> pd.DataFrame:
    """Tag excluded hosts with excluded=True. Hosts are never removed from df."""
    rules = exclusions.get(company) or exclusions.get("__global__")
    if rules:
        df[EXCLUDED_COL] = _exclusion_mask(df, rules)
        n = int(df[EXCLUDED_COL].sum())
        if n:
            logger.info("  Excluded hosts: %d", n)
    else:
        df[EXCLUDED_COL] = False
    return df


# ---------------------------------------------------------------------------
# Metrics helpers
# ---------------------------------------------------------------------------

def _metrics(pool: pd.DataFrame) -> dict:
    total    = len(pool)
    with_edr = int(pool["has_edr"].sum())
    online   = int(pool["edr_online"].sum())
    return {
        "VM_TOTAL":               total,
        "EDR_VM_TOTAL":           with_edr,
        "EDR_VM_ONLINE":          online,
        "EDR_COVERAGE_PCT":       round(100 * with_edr / total, 2) if total else 0.0,
        "EDR_ONLINE_COVERAGE_PCT":round(100 * online   / total, 2) if total else 0.0,
        "VM_WITHOUT_EDR":         total - with_edr,
    }


def _split_metrics(pool: pd.DataFrame) -> tuple[dict, dict]:
    """Return (server metrics, workstation metrics) for the given pool."""
    return (
        _metrics(pool[pool[SOURCE_TYPE_COL] == "server"]),
        _metrics(pool[pool[SOURCE_TYPE_COL] == "workstation"]),
    )


# ---------------------------------------------------------------------------
# Discovery
# ---------------------------------------------------------------------------

def _inventory_company(path: Path) -> str | None:
    """Компания из имени файла инвентаря; None — имя не по схеме."""
    for suffix in INVENTORY_SUFFIXES:
        if path.stem.endswith(suffix):
            return path.stem[: -len(suffix)]
    return None


def discover_companies() -> dict[str, list[Path]]:
    """
    Find companies via *_edr.csv files and attach their inventory files.

    Компанию задаёт выгрузка агентов: без неё считать покрытие не от чего, а
    заводить компанию с пустым пулом агентов нельзя — компании общего тенанта
    показали бы 0% при живых агентах в чужом файле.

    Поэтому инвентарь без выгрузки агентов — не тихий пропуск, а предупреждение:
    четыре компании (project-g, project-h, project-i, project-j) так полгода не
    попадали ни в одну метрику. Лечится это конфигом EDR, а не кодом, но
    молчать об этом нельзя.
    """
    edr_files = list(DATA_DIR.glob(f"*{EDR_FILE_SUFFIX}.csv"))
    if not edr_files:
        logger.warning("No EDR files (*_edr.csv) found")
        return {}

    known = {path.stem[: -len(EDR_FILE_SUFFIX)]: path for path in edr_files}
    inventory: dict[str, list[Path]] = {}
    unknown: list[str] = []
    for path in sorted(DATA_DIR.glob("*.csv")):
        if path.name in GENERATED_CSV or path.stem.endswith(EDR_FILE_SUFFIX):
            continue
        company = _inventory_company(path)
        if company is None:
            unknown.append(path.name)
        else:
            inventory.setdefault(company, []).append(path)

    result: dict[str, list[Path]] = {}
    for company, edr_path in known.items():
        vm_files = inventory.get(company)
        if vm_files:
            result[company] = vm_files
            logger.info(
                "Company '%s': EDR=%s, host files=%s",
                company, edr_path.name, [f.name for f in vm_files],
            )
        else:
            logger.warning("Company '%s': no host files found (%s*.csv)", company, company)

    for company in sorted(set(inventory) - set(known)):
        logger.warning(
            "Инвентарь без выгрузки агентов: компания '%s' (%s) не попадёт ни в одну "
            "метрику — нет %s%s.csv. Если её агенты лежат в общем тенанте, добавить "
            "компанию в конфиг EDR",
            company, ", ".join(f.name for f in inventory[company]), company, EDR_FILE_SUFFIX,
        )
    if unknown:
        logger.warning(
            "CSV не отнесены ни к одной компании: %s — имя должно оканчиваться на %s",
            ", ".join(unknown), " / ".join(INVENTORY_SUFFIXES),
        )

    return result


# ---------------------------------------------------------------------------
# Data loading
# ---------------------------------------------------------------------------

def _first_non_empty(values: pd.Series):
    """Первое непустое значение колонки внутри группы (иначе — первое)."""
    for value in values:
        if pd.notna(value) and str(value).strip() != "":
            return value
    return values.iloc[0] if len(values) else pd.NA


def _collapse_hosts(df: pd.DataFrame) -> pd.DataFrame:
    """
    Одна строка на хост: дубли склеиваются, а не отбрасываются.

    Доменный сервер попадает и в AD, и в облачную выгрузку. Выбросив одну из
    строк, потеряли бы либо sourceip (нужен для матчинга по IP), либо dn (нужен
    для исключений по OU). Поэтому: sourceip объединяем, dn/enabled приходят из
    AD-строки, managed — из облачной, source_type=server, если хост есть в
    облаке (VDI тоже считаем сервером), факт присутствия в домене остаётся в
    in_ad. Ключ группировки нормализован: AD пишет 'PROJ-B-…', облако — 'proj-b-…'.
    """
    key = _norm_host(df[VM_HOSTNAME_COL]).rename("_key")
    if not key.duplicated().any():
        return df

    def _merge_ips(values: pd.Series) -> str:
        seen: dict[str, None] = {}
        for value in values:
            seen.update(dict.fromkeys(_split_ips(value)))
        return ",".join(seen)

    agg = {col: _first_non_empty for col in df.columns}
    agg[SOURCE_TYPE_COL] = lambda s: "server" if (s == "server").any() else "workstation"
    agg[IN_AD_COL] = "any"
    if VM_SOURCEIP_COL in df.columns:
        agg[VM_SOURCEIP_COL] = _merge_ips

    collapsed = df.groupby(key, sort=False).agg(agg).reset_index(drop=True)
    logger.info("  Дублей hostname склеено: %d", len(df) - len(collapsed))
    return collapsed


def load_vm(company: str, file_paths: list[Path]) -> pd.DataFrame:
    """
    Load and concatenate all host files for a company.
    Adds source_type='workstation' for -ad.csv files, 'server' for the rest.
    Hosts present in several files are merged into one row (see _collapse_hosts).
    """
    dfs = []
    for fp in file_paths:
        try:
            df = pd.read_csv(fp)
        except Exception as e:
            logger.error("Cannot read %s: %s", fp.name, e)
            continue

        if VM_HOSTNAME_COL not in df.columns:
            logger.warning("Skipping %s — no '%s' column", fp.name, VM_HOSTNAME_COL)
            continue

        from_ad = fp.stem.endswith(AD_FILE_SUFFIX)

        # Keep only the columns we need
        cols = [VM_HOSTNAME_COL]
        for optional in (VM_OS_HOSTNAME_COL, VM_SOURCEIP_COL):
            if optional in df.columns:
                cols.append(optional)
        if MANAGED_COL in df.columns:
            cols.append(MANAGED_COL)
        if from_ad:
            cols += [c for c in (VM_ENABLED_COL, VM_DN_COL) if c in df.columns]
        # Тип из данных: AD отдаёт и серверы, и рабочие места, и различает их
        # колонкой. Без колонки — по имени файла, как в старых выгрузках.
        has_type = SOURCE_TYPE_COL in df.columns
        if has_type:
            cols.append(SOURCE_TYPE_COL)

        df = df[cols].copy()
        df[COMPANY_COL] = company
        if has_type:
            df[SOURCE_TYPE_COL] = (
                df[SOURCE_TYPE_COL].astype(str).str.strip().str.lower()
                .where(lambda s: s.isin(["server", "workstation"]),
                       "workstation" if from_ad else "server")
            )
        else:
            df[SOURCE_TYPE_COL] = "workstation" if from_ad else "server"
        df[IN_AD_COL] = from_ad
        dfs.append(df)

    if not dfs:
        return pd.DataFrame()

    combined = pd.concat(dfs, ignore_index=True)
    if MANAGED_COL not in combined.columns:
        combined[MANAGED_COL] = ""
    combined[MANAGED_COL] = combined[MANAGED_COL].fillna("").astype(str)
    combined = _collapse_hosts(combined)
    logger.info(
        "Company '%s': %d unique hosts (%d servers, %d workstations)",
        company, len(combined),
        (combined[SOURCE_TYPE_COL] == "server").sum(),
        (combined[SOURCE_TYPE_COL] == "workstation").sum(),
    )
    return combined


def load_edr(company: str) -> pd.DataFrame:
    """Load EDR agent list for a company. Returns empty DataFrame if not found."""
    fp = DATA_DIR / f"{company}_edr.csv"
    if not fp.exists():
        logger.warning("EDR file not found: %s", fp.name)
        return pd.DataFrame()
    try:
        df = pd.read_csv(fp)
        if EDR_NAME_COL not in df.columns:
            logger.warning("%s has no '%s' column", fp.name, EDR_NAME_COL)
            return pd.DataFrame()
        # Берём все колонки как есть, без отбора списком: отбор дважды отключал
        # логику молча (сначала проход по IP — из-за имени колонки, потом
        # подсказки по lastuser — колонку просто забыли внести в список), а
        # выигрыша не давал. Файл пишем мы сами, колонок два десятка, и в отчёт
        # отсюда ничего не попадает — в него идут только колонки инвентаря.
        return df
    except Exception as e:
        logger.error("Cannot read %s: %s", fp.name, e)
        return pd.DataFrame()


# ---------------------------------------------------------------------------
# EDR matching
# ---------------------------------------------------------------------------

# Имя агента, состоящее только из цифр и точек, — не идентификатор машины.
# macOS берёт LocalHostName из сетевого имени и режет его по первой точке: хост
# с именем '192.168.1.15' регистрируется в EDR как '192', и под этим именем
# сходятся разные машины (в выгрузке от 2026-08-12 — два ноутбука разных
# пользователей). Такие записи из матчинга по имени исключаем.
_NUMERIC_AGENT_NAME = re.compile(r"^[\d.]+$")


def _agent_key(edr_df: pd.DataFrame) -> pd.Series:
    """
    Ключ записи агента: имя, а для обрезанных имён — displayName.

    Три разных мака приезжают под одним именем '192', но в панели они видны как
    192.168.1.11 / .15 / .8 — это их displayName. Взяв его за ключ, мы получаем
    три различимые записи вместо одной схлопнутой: дедуп перестаёт терять две из
    трёх, а в aliases.yaml можно сослаться на конкретную машину, а не на
    «какой-нибудь 192». Матчиться по такому ключу всё равно нельзя (это адрес, а
    не имя хоста) — его отсеет _drop_unusable_agent_names.
    """
    key = _norm_host(edr_df[EDR_NAME_COL])
    if EDR_DISPLAYNAME_COL not in edr_df.columns:
        return key
    shown = _norm_host(edr_df[EDR_DISPLAYNAME_COL])
    truncated = key.str.match(_NUMERIC_AGENT_NAME) & shown.ne("") & shown.ne("NAN")
    return key.mask(truncated, shown)


def _drop_unusable_agent_names(edr_df: pd.DataFrame) -> pd.DataFrame:
    """Выбросить записи EDR, чей ключ не может служить ключом сопоставления."""
    unusable = edr_df["_host"].str.match(_NUMERIC_AGENT_NAME)
    if unusable.any():
        logger.warning(
            "  EDR: %d записей с неинформативным именем агента (%s) — по имени не матчим, "
            "ссылаться на них можно из aliases.yaml",
            int(unusable.sum()),
            ", ".join(sorted(set(edr_df.loc[unusable, "_host"]))[:5]),
        )
    return edr_df[~unusable]


def _sort_agents(edr_df: pd.DataFrame, has_online: bool, has_seen: bool) -> pd.DataFrame:
    """
    Записи агентов от самой достоверной к наименее: сначала живые, среди равных —
    с самой свежей регистрацией. На этот порядок опираются все keep='first' ниже,
    поэтому он задаётся один раз и до всех проходов.
    """
    sort_cols = (["_online"] if has_online else []) + (["_seen"] if has_seen else [])
    return edr_df.sort_values(sort_cols, ascending=False, kind="mergesort") if sort_cols else edr_df


def _dedup_agents(edr_df: pd.DataFrame) -> pd.DataFrame:
    """
    Одна запись на имя хоста.

    Переустановка агента создаёт в EDR новую запись с другим id: старая offline,
    новая online. Без схлопывания хост размножился бы в отчёте и раздул VM_TOTAL.
    Порядок задан в _sort_agents, поэтому keep='first' — это не «первый
    попавшийся», а «живой агент, среди равных самая свежая регистрация».
    """
    dup_agents = int(edr_df.duplicated(subset=["_host"]).sum())
    if dup_agents:
        logger.info("  EDR: %d дублирующихся записей агентов схлопнуто", dup_agents)
    _warn_name_collisions(edr_df)
    return edr_df.drop_duplicates(subset=["_host"], keep="first")


def _warn_name_collisions(edr_df: pd.DataFrame) -> None:
    """
    Отделить переустановку от разных машин под одним именем.

    Почти все дубли — перерегистрация одной машины: агент ставится до ввода в
    домен (domain=WORKGROUP, версия ниже, sourceIP пуст), потом появляется вторая
    запись; osname у таких записей совпадает. Разные машины выдаёт именно osname
    (проверено 2026-08-12: из 22 групп дублей 20 — переустановка, 2 — коллизия:
    три мака с именем '192' и два MACBOOK-AIR-ADMIN). Схлопывание в этом случае
    прячет машину, поэтому пишем предупреждение — разбирается это в панели EDR,
    не кодом.
    """
    if EDR_OSNAME_COL not in edr_df.columns:
        return
    dups = edr_df[edr_df.duplicated(subset=["_host"], keep=False)]
    collisions = []
    for name, group in dups.groupby("_host", sort=False):
        if group[EDR_OSNAME_COL].astype(str).nunique() <= 1:
            continue
        # displayName — то, под чем машина видна в панели EDR: у обрезанных имён
        # это единственный способ понять, о каких хостах речь ('192' в панели
        # показан как 192.168.1.11 / .15 / .8)
        shown = (
            sorted(set(group[EDR_DISPLAYNAME_COL].astype(str)))
            if EDR_DISPLAYNAME_COL in group.columns else []
        )
        collisions.append(f"{name} ({', '.join(shown)})" if shown else name)
    if collisions:
        logger.warning(
            "  EDR: под одним именем разные машины (различается ОС): %s — "
            "в покрытии останется одна, разобрать в панели",
            "; ".join(sorted(collisions)),
        )


def _name_usable(out: pd.DataFrame) -> pd.Series:
    """
    Можно ли матчить этот хост по имени. Нельзя, когда имя занято машинами
    разных компаний: агент с таким именем один, а хостов несколько. Правило
    распространяется на все имя-подобные ключи (hostname, os_hostname,
    inv_hostname) — os_hostname у одноимённых ВМ тоже совпадает. Ручной alias
    остаётся: там человек указал конкретного агента.
    """
    if NAME_SHARED_COL not in out.columns:
        return pd.Series(True, index=out.index)
    return ~out[NAME_SHARED_COL].astype(bool)


def _claim_agent(out: pd.DataFrame, vm_idx, agent: pd.Series, how: str, has_online: bool,
                 claimed: set[str] | None = None) -> None:
    """Отметить хост покрытым агентом, найденным не по основному имени."""
    out.at[vm_idx, "has_edr"]      = True
    out.at[vm_idx, MATCHED_BY_COL] = how
    if has_online:
        out.at[vm_idx, "edr_online"] = bool(agent["_online"])
    if "_seen_ts" in agent.index:
        out.at[vm_idx, "edr_last_seen"] = agent["_seen_ts"]
    if claimed is not None:
        claimed.add(agent["_host"])


def _warn_ip_contradicts_name(out: pd.DataFrame, edr_df: pd.DataFrame) -> None:
    """
    Имя сошлось, а адреса противоречат — повод усомниться в матче.

    Требовать совпадения адресов нельзя: у 291 хоста из 420 сматченных адреса
    нет вовсе (AD его не хранит), правило срезало бы две трети верных матчей.
    Зато там, где адрес известен с обеих сторон, он совпадает в 129 случаях из
    129 — поэтому расхождение означает, что под одним именем разные машины.
    """
    if VM_SOURCEIP_COL not in out.columns or EDR_IP_COL not in edr_df.columns:
        return
    agent_ips = {host: set(_split_ips(ip))
                 for host, ip in zip(edr_df["_host"], edr_df[EDR_IP_COL])}
    suspicious = []
    for idx in out.index[out[MATCHED_BY_COL] == "hostname"]:
        theirs = agent_ips.get(out.at[idx, "_host"]) or set()
        ours = set(_split_ips(out.at[idx, VM_SOURCEIP_COL]))
        if theirs and ours and not (theirs & ours):
            suspicious.append(f"{out.at[idx, VM_HOSTNAME_COL]} "
                              f"(хост {','.join(sorted(ours))} против агента {','.join(sorted(theirs))})")
    if suspicious:
        logger.warning(
            "Имя совпало, а адреса разошлись у %d хостов — возможно, это разные "
            "машины под одним именем: %s",
            len(suspicious), "; ".join(suspicious[:5]),
        )


def _match_by_alias(out: pd.DataFrame, by_name: pd.DataFrame, aliases: dict,
                    has_online: bool, claimed: set[str]) -> int:
    """
    Проход по ручным соответствиям из aliases.yaml.

    Дополняет матчинг по имени, а не переопределяет его: применяется только к
    хостам, которые не нашлись сами. Соответствие на несуществующего агента —
    не молчаливый промах, а предупреждение: скорее всего, агент переустановлен
    и запись в файле протухла.
    """
    if not aliases:
        return 0

    agents = by_name.set_index("_host")
    matched, stale = 0, []
    for vm_idx in out.index[~out["has_edr"]]:
        target = aliases.get(out.at[vm_idx, "_host"])
        if not target:
            continue
        if target not in agents.index:
            stale.append(f"{out.at[vm_idx, VM_HOSTNAME_COL]} -> {target}")
            continue
        # ключ агента здесь ушёл в индекс, поэтому отмечаем его отдельно
        _claim_agent(out, vm_idx, agents.loc[target], "alias", has_online)
        claimed.add(target)
        matched += 1
    if stale:
        logger.warning("  aliases.yaml: агент не найден в выгрузке: %s", "; ".join(stale))
    return matched


def _suggest_aliases(out: pd.DataFrame, edr_df: pd.DataFrame) -> None:
    """
    Подсказать кандидатов для aliases.yaml по имени пользователя.

    АРМ часто назван по владельцу ('m-user-a', 'm-proj-c-00020'), а на агенте
    остаётся lastuser ('a.user', 'proj-c-00020'). Это и есть связь, но она
    гевристическая, поэтому автоматически не применяется: подсказка идёт в лог,
    решение и запись в файл — за человеком. Показываем только однозначные пары.
    """
    if EDR_LASTUSER_COL not in edr_df.columns:
        return

    def _login(value) -> str:
        return re.sub(r"[._-]", "", str(value).split("\\")[-1].strip().lower())

    unmatched = out[~out["has_edr"]]
    if unmatched.empty:
        return

    free = edr_df[~edr_df["_host"].isin(set(out.loc[out["has_edr"], "_host"]))]
    by_login: dict[str, list[str]] = {}
    for _, agent in free.iterrows():
        login = _login(agent[EDR_LASTUSER_COL])
        if login:
            by_login.setdefault(login, []).append(str(agent[EDR_NAME_COL]))

    host_logins = {idx: _login(re.sub(r"^[mw]-", "", str(name).lower()))
                   for idx, name in unmatched[VM_HOSTNAME_COL].items()}
    taken = collections.Counter(host_logins.values())
    hints = [
        f"{unmatched.at[idx, VM_HOSTNAME_COL]} -> {by_login[login][0]}"
        for idx, login in host_logins.items()
        if login and taken[login] == 1 and len(by_login.get(login, [])) == 1
    ]
    if hints:
        logger.info("  Кандидаты в aliases.yaml (совпал пользователь, проверить глазами): %s",
                    "; ".join(sorted(hints)))


def _match_by_inventory_hostname(out: pd.DataFrame, edr_df: pd.DataFrame,
                                 has_online: bool, claimed: set[str]) -> int:
    """
    Проход по имени, которое агент рапортует о себе сам (inventory.hostname).

    Заполняется только у обогащённых записей — тех, чьё имя в списке агентов
    ничего не идентифицирует. Именно здесь возвращаются доменные маки: агент с
    именем '192' в inventory зовётся m-proj-c-00026, и этот хост есть в AD.
    Ищем по полному набору записей, а не по схлопнутым: у трёх агентов с именем
    '192' восстановленные имена разные, и дедуп по имени оставил бы одно.

    Меняет out на месте, возвращает число доматченных хостов.
    """
    if EDR_INV_HOSTNAME_COL not in edr_df.columns:
        return 0

    candidates = out.index[~out["has_edr"] & _name_usable(out)]
    if candidates.empty:
        return 0

    inv = edr_df[edr_df[EDR_INV_HOSTNAME_COL].astype(str).str.strip().ne("")].copy()
    if inv.empty:
        return 0
    inv["_inv"] = _norm_host(inv[EDR_INV_HOSTNAME_COL])
    # имя из inventory совпадает с именем агента — новой информации нет;
    # агент, уже занятый своим хостом, не переиспользуется
    taken = set(out.loc[out["has_edr"], "_host"])
    inv = inv[(inv["_inv"] != inv["_host"]) & ~inv["_host"].isin(taken)]
    lookup = inv.drop_duplicates(subset=["_inv"], keep="first").set_index("_inv")

    matched = 0
    for vm_idx in candidates:
        key = out.at[vm_idx, "_host"]
        if key not in lookup.index:
            continue
        _claim_agent(out, vm_idx, lookup.loc[key], "inv_hostname", has_online, claimed)
        matched += 1
    return matched


def _match_by_os_hostname(out: pd.DataFrame, edr_df: pd.DataFrame,
                          has_online: bool, claimed: set[str]) -> int:
    """
    Промежуточный проход: по hostname внутри ОС (колонка os_hostname).

    Есть только у выгрузок SberCloud: у VK Cloud максимальная microversion Nova
    2.42, а поле появляется с 2.90. Это **дополнительный** ключ, а не замена
    имени ВМ: os_hostname фиксируется при создании и не следует за
    переименованием инстанса, поэтому у части ВМ он указывает на чужое имя
    (проверено 2026-08-12: 19 расхождений из 172, 13 из них — не про символы).
    Отсюда защита: агент, уже занятый матчем по hostname, вторым ключом не
    переиспользуется — иначе пары вроде proj-b-prod-lb-1 / proj-b-prod-vault-lb-1,
    где в EDR есть агенты под обоими именами, дали бы ложный матч.

    Меняет out на месте, возвращает число доматченных хостов.
    """
    if VM_OS_HOSTNAME_COL not in out.columns:
        return 0

    candidates = out.index[~out["has_edr"] & _name_usable(out)]
    if candidates.empty:
        return 0

    taken = set(out.loc[out["has_edr"], "_host"])
    agents = {host: idx for idx, host in edr_df["_host"].items() if host not in taken}
    matched = 0
    for vm_idx in candidates:
        key = _norm_host(pd.Series([out.at[vm_idx, VM_OS_HOSTNAME_COL]])).iloc[0]
        if not key or key == "NAN" or key not in agents:
            continue
        _claim_agent(out, vm_idx, edr_df.loc[agents[key]], "os_hostname", has_online, claimed)
        matched += 1
    return matched


def _match_by_ip(out: pd.DataFrame, edr_df: pd.DataFrame,
                 has_online: bool, claimed: set[str]) -> int:
    """
    Второй проход: сопоставление по IP для хостов, не найденных по имени.

    sourceip в выгрузке EDR — адрес, с которого подключился агент (NAT/VIP), а не
    идентификатор машины: 36 адресов приходятся на 88 разных хостов. Поэтому
    адрес годится как ключ, только если уникален с обеих сторон; неоднозначные
    выбрасываем целиком, а не берём первый попавшийся. Проход только для
    серверов: у АРМ адрес выдаёт DHCP, и в AD-выгрузке он протухает.

    Меняет out на месте, возвращает число доматченных хостов.
    """
    if VM_SOURCEIP_COL not in out.columns or EDR_IP_COL not in edr_df.columns:
        return 0

    candidates = out.index[~out["has_edr"] & (out[SOURCE_TYPE_COL] == "server")]
    if candidates.empty:
        return 0

    # Уникальность на стороне ВМ считаем по всем строкам компании, а не только по
    # кандидатам: адрес, поделённый с уже сматченным хостом, тоже неоднозначен.
    vm_ips, vm_unique = _unique_ips(out[VM_SOURCEIP_COL])
    edr_ips, edr_unique = _unique_ips(edr_df[EDR_IP_COL])
    usable = vm_unique & edr_unique
    shared = set(vm_ips) & set(edr_ips)
    if shared:
        logger.info(
            "  IP-проход: адресов, общих с EDR: %d, из них годных (уникальны с обеих сторон): %d",
            len(shared), len(shared & usable),
        )
    if not usable:
        return 0

    edr_by_ip = {ip: idx for idx, ip in edr_ips.items() if ip in usable}
    matched = 0
    for vm_idx in candidates:
        hits = {edr_by_ip[ip] for ip in _split_ips(out.at[vm_idx, VM_SOURCEIP_COL])
                if ip in edr_by_ip}
        if len(hits) != 1:
            continue  # ни одного годного адреса либо разные агенты — не гадаем
        _claim_agent(out, vm_idx, edr_df.loc[hits.pop()], "ip", has_online, claimed)
        matched += 1
    return matched


def _merge_with_edr(vm_df: pd.DataFrame, edr_df: pd.DataFrame,
                    aliases: dict | None = None) -> pd.DataFrame:
    """
    Join vm_df with edr_df in five passes, from the most reliable key down:
      1. hostname (case-insensitive, '_' == '-');
      2. ручные соответствия из aliases.yaml;
      3. inv_hostname — имя, которое агент рапортует о себе сам;
      4. os_hostname из выгрузки облака (только SberCloud);
      5. IP — только серверы и только адреса, уникальные с обеих сторон.
    Adds has_edr, edr_online, edr_last_seen and matched_by columns to vm_df.
    """
    has_online = EDR_ONLINE_COL in edr_df.columns
    has_seen   = EDR_LASTSEEN_COL in edr_df.columns

    edr_df = edr_df.copy()
    edr_df["_host"] = _agent_key(edr_df)
    if has_online:
        edr_df["_online"] = edr_df[EDR_ONLINE_COL].astype(str).str.lower().eq("true")
    if has_seen:
        seen = pd.to_datetime(edr_df[EDR_LASTSEEN_COL], errors="coerce", utc=True)
        edr_df["_seen"] = seen
        # unix-время последней связи агента (UTC) — для окна «молчит»
        edr_df["_seen_ts"] = seen.apply(lambda t: t.timestamp() if pd.notna(t) else float("nan"))

    # Проходы по имени идут по схлопнутым записям с пригодным именем; для оценки
    # однозначности адресов нужны все записи, включая отброшенные, иначе чужой
    # адрес может показаться уникальным.
    edr_df = _sort_agents(edr_df, has_online, has_seen)
    # by_any — все записи, схлопнутые по имени: на них ссылается aliases.yaml,
    # ради обрезанных имён вроде '192' он и нужен. by_name — то же за вычетом
    # имён, которые машину не идентифицируют: только по ним матчим автоматически.
    by_any = _dedup_agents(edr_df)
    by_name = _drop_unusable_agent_names(by_any)

    out = vm_df.copy()
    out["_host"] = _norm_host(out[VM_HOSTNAME_COL])

    # Pass 1: hostname. Хосты, чьё имя занято машинами других компаний, пропускаем:
    # имя перестало быть ключом, остаются IP, alias и os_hostname.
    out["has_edr"] = out["_host"].isin(set(by_name["_host"])) & _name_usable(out)
    out["edr_online"] = (
        out["_host"].map(dict(zip(by_name["_host"], by_name["_online"]))).fillna(False).astype(bool)
        if has_online else pd.Series(False, index=out.index)
    )
    out["edr_last_seen"] = (
        out["_host"].map(dict(zip(by_name["_host"], by_name["_seen_ts"])))
        if has_seen else float("nan")
    )
    out[MATCHED_BY_COL] = out["has_edr"].map({True: "hostname", False: ""})
    matched_by_host = int(out["has_edr"].sum())
    # Агенты, которых забрал хоть какой-то хост. Нужны, чтобы отличить
    # «агент есть, а инвентаря нет» от обычного непокрытия.
    claimed: set[str] = set(out.loc[out["has_edr"], "_host"])

    _warn_ip_contradicts_name(out, edr_df)

    # Pass 2: ручные соответствия (человек знает то, чего нет в данных)
    matched_by_alias = _match_by_alias(out, by_any, aliases or {}, has_online, claimed)

    # Pass 3: имя, которое агент рапортует о себе сам (обогащение из /agents/{id})
    matched_by_inv = _match_by_inventory_hostname(out, edr_df, has_online, claimed)

    # Pass 4: hostname внутри ОС (есть только у SberCloud)
    matched_by_os = _match_by_os_hostname(out, by_name, has_online, claimed)

    # Pass 5: IP (только серверы, только однозначные адреса)
    matched_by_ip = _match_by_ip(out, edr_df, has_online, claimed)

    out.loc[~out["has_edr"], "edr_last_seen"] = float("nan")

    logger.info(
        "  Matched by hostname: %d, additionally by alias: %d, by inv_hostname: %d, "
        "by os_hostname: %d, by IP: %d",
        matched_by_host, matched_by_alias, matched_by_inv, matched_by_os, matched_by_ip,
    )
    _suggest_aliases(out, edr_df)

    # Отдаём наружу пул агентов и тех из них, кто нашёл свой хост: по одной
    # компании судить нельзя — компании общего тенанта делят один _edr.csv,
    # и чужие агенты выглядели бы бесхозными. Сводит это build_report.
    out.attrs["agent_keys"] = set(by_any["_host"])
    out.attrs["claimed_agents"] = claimed

    out.drop(columns=["_host"], inplace=True, errors="ignore")
    return out


# ---------------------------------------------------------------------------
# Pool filter
# ---------------------------------------------------------------------------

def _in_pool(df: pd.DataFrame) -> pd.Series:
    """
    True for hosts that should be counted in metrics.
    Excluded hosts are always False.
    Servers:      non-empty sourceip  +  hostname doesn't start with TEMP prefix.
    Workstations: enabled account     +  hostname doesn't start with TEMP prefix.
    """
    not_temp     = ~df[VM_HOSTNAME_COL].astype(str).str.upper().str.startswith(TEMP_HOSTNAME_PREFIX)
    not_excluded = ~df[EXCLUDED_COL].astype(bool)
    not_managed  = (
        df[MANAGED_COL].fillna("").astype(str) == ""
        if MANAGED_COL in df.columns
        else pd.Series(True, index=df.index)
    )
    is_ws        = df[SOURCE_TYPE_COL] == "workstation"

    has_ip = (
        df[VM_SOURCEIP_COL].notna() & (df[VM_SOURCEIP_COL].astype(str).str.strip() != "")
        if VM_SOURCEIP_COL in df.columns
        else pd.Series(False, index=df.index)
    )
    is_enabled = (
        df[VM_ENABLED_COL].astype(str).str.lower().isin(["true", "1", "yes"])
        if VM_ENABLED_COL in df.columns
        else pd.Series(True, index=df.index)
    )

    # Сервер попадает в пул, если у него есть адрес (облачная выгрузка) либо он
    # доменный и учётка включена. Требовать адрес от всех было бы наследием тех
    # времён, когда серверы приезжали только из облаков: AD адресов не хранит, и
    # 104 доменных сервера молча не попали бы в знаменатель.
    in_domain = df[IN_AD_COL].astype(bool) if IN_AD_COL in df.columns else pd.Series(False, index=df.index)
    server_ok = has_ip | (in_domain & is_enabled)
    return not_excluded & not_managed & not_temp & ((~is_ws & server_ok) | (is_ws & is_enabled))


# ---------------------------------------------------------------------------
# Per-company processing
# ---------------------------------------------------------------------------

def process_company(
    company: str,
    vm_df: pd.DataFrame,
    exclusions: dict,
    aliases: dict | None = None,
) -> tuple[pd.DataFrame, dict]:
    if vm_df.empty:
        return pd.DataFrame(), {}

    # Apply exclusions before EDR matching
    vm_df = _apply_exclusions(vm_df, exclusions, company)

    edr_df = load_edr(company)
    if not edr_df.empty:
        df = _merge_with_edr(vm_df, edr_df, (aliases or {}).get(company))
    else:
        df = vm_df.copy()
        df["has_edr"]      = False
        df["edr_online"]   = False
        df["edr_last_seen"] = float("nan")
        df[MATCHED_BY_COL] = ""

    df["in_pool"] = _in_pool(df)

    pool = df[df["in_pool"]]
    srv, ws = _split_metrics(pool)
    m = _metrics(pool)
    m["SERVERS"]      = srv
    m["WORKSTATIONS"] = ws
    m["EXCLUDED"]     = int(df[EXCLUDED_COL].sum())
    m["MANAGED"]      = int((df[MANAGED_COL] != "").sum())

    logger.info(
        "  Pool: total=%d (servers=%d, workstations=%d), with_edr=%d (%.2f%%), "
        "excluded=%d, managed=%d",
        m["VM_TOTAL"], srv["VM_TOTAL"], ws["VM_TOTAL"],
        m["EDR_VM_TOTAL"], m["EDR_COVERAGE_PCT"], m["EXCLUDED"], m["MANAGED"],
    )
    return df, m


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def _resolve_cross_company(frames: dict[str, pd.DataFrame]) -> dict[str, pd.DataFrame]:
    """
    Хост принадлежит ровно одной компании. Разбираем случаи, когда источники
    сказали разное.

    Облачная выгрузка сильнее доменной: ВМ живёт в аккаунте конкретной компании,
    это факт, тогда как в AD хост попадает к компании по OU, паттернам или
    вовсе по `default_company`. Поэтому AD-строка переезжает к той компании, у
    которой есть облачная строка того же хоста, и склеивается с ней (так
    `dependencytrack` и `teleport-db` числились за project-a, хотя это ВМ project-c).

    Если облачных строк несколько и у разных компаний — это **разные машины с
    одинаковым именем** (`lb-waf-prod-01` у project-b и project-c: разные адреса,
    разные проекты). Склеивать их нельзя, и матчить по имени тоже: тенант EDR
    общий, агент с таким именем один, и обе машины помечались покрытыми — одна
    из них чужим агентом. Такие хосты помечаются `name_shared`, и проход по
    имени их пропускает; остаются IP, alias и os_hostname.
    """
    if len(frames) < 2:
        return frames

    keys = {company: _norm_host(df[VM_HOSTNAME_COL]) for company, df in frames.items() if not df.empty}
    owners: dict[str, list[str]] = {}
    for company, key in keys.items():
        for value in set(key):
            owners.setdefault(value, []).append(company)

    moved, shared = 0, []
    for host, companies in owners.items():
        if len(companies) < 2:
            continue
        from_cloud = [c for c in companies
                      if (~frames[c].loc[keys[c] == host, IN_AD_COL].astype(bool)).any()]
        if len(from_cloud) == 1:
            target = from_cloud[0]
            for company in companies:
                if company == target:
                    continue
                rows = frames[company][keys[company] == host]
                frames[target] = pd.concat([frames[target], rows.assign(**{COMPANY_COL: target})],
                                           ignore_index=True)
                frames[company] = frames[company][keys[company] != host]
                keys[company] = _norm_host(frames[company][VM_HOSTNAME_COL])
                moved += len(rows)
            frames[target] = _collapse_hosts(frames[target])
            keys[target] = _norm_host(frames[target][VM_HOSTNAME_COL])
        else:
            shared.append(host)
            for company in companies:
                frames[company].loc[keys[company] == host, NAME_SHARED_COL] = True

    if moved:
        logger.info("  Строк перенесено к владельцу облачной ВМ: %d", moved)
    if shared:
        logger.warning(
            "Одинаковое имя у машин разных компаний: %s — это разные хосты, "
            "по имени их не матчим (агент с таким именем достался бы обоим)",
            ", ".join(sorted(shared)),
        )
    for company, df in frames.items():
        if NAME_SHARED_COL not in df.columns:
            frames[company] = df.assign(**{NAME_SHARED_COL: False})
        else:
            frames[company][NAME_SHARED_COL] = df[NAME_SHARED_COL].fillna(False).astype(bool)
    return frames


def _count_agents_without_inventory(tenants: dict[frozenset, dict],
                                    company_metrics: dict[str, dict]) -> None:
    """
    Агенты, не сматченные ни с одним хостом, — сигнал о потерянном источнике.

    Считается по тенанту, а не по компании: компании общего тенанта делят один
    `_edr.csv`, и агент соседней компании иначе выглядел бы бесхозным (у project-b
    «пропали» бы почти все 452 записи). Число само по себе ничего не чинит, но
    только оно и видно снаружи, когда инвентарь целиком отсутствует: за ним
    прячутся VDI-пул, чужой тенант облака, офисный сегмент и несобираемый
    гипервизор.
    """
    for agents, tenant in tenants.items():
        orphans = sorted(agents - tenant["claimed"])
        for company in tenant["companies"]:
            company_metrics[company]["AGENTS_WITHOUT_INVENTORY"] = len(orphans)
        if orphans:
            logger.warning(
                "Агентов без хоста в инвентаре: %d из %d (компании: %s). Примеры: %s",
                len(orphans), len(agents), ", ".join(sorted(tenant["companies"])),
                ", ".join(orphans[:5]),
            )


def build_report() -> tuple[pd.DataFrame, dict]:
    """
    Run the whole pipeline over DATA_DIR.

    Returns (per-host frame, aggregated metrics). Both are empty when there is
    nothing to report. Used by main() and by the metrics exporter — keep it free
    of side effects (no file writes, no logging of file paths) so callers decide
    what to persist.
    """
    company_files = discover_companies()
    if not company_files:
        logger.error("No companies found.")
        return pd.DataFrame(), {}

    exclusions = load_exclusions()
    aliases = load_aliases()
    company_metrics: dict[str, dict] = {}
    reports: list[pd.DataFrame] = []

    # Инвентарь всех компаний читаем до анализа: кому принадлежит хост, видно
    # только целиком — облачная выгрузка одной компании перебивает AD другой.
    inventory = _resolve_cross_company(
        {company: load_vm(company, paths) for company, paths in company_files.items()})

    tenants: dict[frozenset, dict] = {}
    for company, vm_df in inventory.items():
        logger.info("=== Processing company '%s' ===", company)
        df, m = process_company(company, vm_df, exclusions, aliases)
        if df.empty:
            logger.warning("Company '%s' skipped — no data", company)
            continue
        reports.append(df)
        company_metrics[company] = m
        # Тенант опознаём по самому пулу агентов: компании одного тенанта тянут
        # список одним запросом и получают побайтово одинаковый _edr.csv.
        agents = frozenset(df.attrs.get("agent_keys") or ())
        if agents:
            tenant = tenants.setdefault(agents, {"claimed": set(), "companies": []})
            tenant["claimed"] |= df.attrs.get("claimed_agents") or set()
            tenant["companies"].append(company)

    _count_agents_without_inventory(tenants, company_metrics)

    if not reports:
        logger.error("No data to report")
        return pd.DataFrame(), {}

    final = pd.concat(reports, ignore_index=True)
    pool  = final[final["in_pool"]]
    srv_all, ws_all = _split_metrics(pool)
    overall = _metrics(pool)
    overall["SERVERS"]      = srv_all
    overall["WORKSTATIONS"] = ws_all
    overall["EXCLUDED"]     = int(final[EXCLUDED_COL].sum())
    overall["MANAGED"]      = int((final[MANAGED_COL] != "").sum())
    # По тенантам, а не сумма по компаниям: у компаний общего тенанта это число
    # одно и то же, и сложение посчитало бы одних и тех же агентов четырежды.
    overall["AGENTS_WITHOUT_INVENTORY"] = sum(
        len(agents - tenant["claimed"]) for agents, tenant in tenants.items()
    )
    overall["COMPANIES"]    = company_metrics
    return final, overall


def main() -> None:
    final, overall = build_report()
    if final.empty:
        return

    srv_all = overall["SERVERS"]
    ws_all  = overall["WORKSTATIONS"]
    company_metrics = overall["COMPANIES"]

    final.to_csv(OUTPUT_CSV, index=False, encoding="utf-8")
    OUTPUT_JSON.write_text(
        json.dumps(overall, indent=2, ensure_ascii=False), encoding="utf-8"
    )

    # --- Summary log ---
    sep = "=" * 60

    def log_row(label: str, m: dict) -> None:
        logger.info(
            "%s  total=%-4d  edr=%-4d (%.1f%%)  online=%-4d (%.1f%%)  no_edr=%d",
            label,
            m["VM_TOTAL"],
            m["EDR_VM_TOTAL"],       m["EDR_COVERAGE_PCT"],
            m["EDR_VM_ONLINE"],      m["EDR_ONLINE_COVERAGE_PCT"],
            m["VM_WITHOUT_EDR"],
        )

    logger.info(sep)
    logger.info("EDR COVERAGE REPORT")
    logger.info(sep)
    log_row("Overall        ", overall)
    log_row("  Servers      ", srv_all)
    log_row("  Workstations ", ws_all)
    logger.info("  Excluded: %d hosts (not counted in metrics)", overall["EXCLUDED"])
    logger.info("  Managed:  %d hosts (agent impossible, not counted)", overall["MANAGED"])
    logger.info("")
    logger.info("Per company:")
    for comp, m in company_metrics.items():
        logger.info("  %s  (excluded: %d)", comp, m.get("EXCLUDED", 0))
        log_row("    Overall        ", m)
        log_row("    Servers        ", m["SERVERS"])
        log_row("    Workstations   ", m["WORKSTATIONS"])
    logger.info(sep)
    logger.info("Report  -> %s", OUTPUT_CSV)
    logger.info("Metrics -> %s", OUTPUT_JSON)
    logger.info(sep)


if __name__ == "__main__":
    main()
