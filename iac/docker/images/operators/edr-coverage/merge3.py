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

# Directory with source CSVs and results. In the exporter container this is /data.
DATA_DIR = Path(os.environ.get("EDR_DATA_DIR", "."))
EXCLUSIONS_FILE = DATA_DIR / "exclusions.yaml"
# Mappings "host -> agent name" that cannot be derived from the data: Macs
# register in EDR under a local name; the domain name is in no API field.
ALIASES_FILE = DATA_DIR / "aliases.yaml"

# Column names
VM_HOSTNAME_COL = "hostname"
VM_OS_HOSTNAME_COL = "os_hostname"  # in-guest hostname (SberCloud only, see below)
VM_SOURCEIP_COL = "sourceip"
VM_ENABLED_COL  = "enabled"    # present in -ad.csv
VM_DN_COL       = "dn"         # present in -ad.csv
EDR_NAME_COL    = "name"
EDR_ONLINE_COL  = "isonline"
# Column names in *_edr.csv are written by API_TO_CSV in vendor-edr.py. All
# lowercase. A mismatch here silently breaks a whole matching pass.
EDR_IP_COL      = "sourceip"   # optional IP column in EDR files
EDR_LASTSEEN_COL = "lastseenat"  # last agent contact time (for the silence window)
EDR_OSNAME_COL  = "osname"     # only for name-duplicate analysis, not used in matching
EDR_LASTUSER_COL = "lastuser"  # only for aliases.yaml hints
# Name under which the agent is shown in the EDR console: usually an FQDN; for
# truncated names the only way to identify the machine ('192' is shown as 192.168.1.11).
EDR_DISPLAYNAME_COL = "displayname"
# Name the agent reports about itself (inventory.hostname from /agents/{id}).
# Filled only on enriched records — those whose list name does not identify
# a machine; for agent '192' this holds the real domain name.
EDR_INV_HOSTNAME_COL = "inv_hostname"
COMPANY_COL     = "company"
SOURCE_TYPE_COL = "source_type"
EXCLUDED_COL    = "excluded"
# how the host was matched to an agent: hostname | alias | inv_hostname | os_hostname | ip | ''
MATCHED_BY_COL  = "matched_by"
IN_AD_COL       = "in_ad"       # host is in the AD export (domain-joined)
# Hostname is used by machines of different companies — do not match such a host
# by name: there is one agent with that name and several machines, so it would
# be given to all of them at once
NAME_SHARED_COL = "name_shared"
# Managed-service kind from the cloud export ('' — ordinary VM). An agent cannot
# be installed on those nodes, so they stay out of the counting pool, but they
# remain in the report and metrics — otherwise a shrinking denominator would
# go unnoticed.
MANAGED_COL     = "managed"

TEMP_HOSTNAME_PREFIX = "CL1"   # temporary VMs to skip
AD_FILE_SUFFIX       = "-ad"   # marks a file as workstation source
EDR_FILE_SUFFIX      = "_edr"  # {company}_edr.csv — agent export
# Inventory file suffixes. The company name is taken from them, not a prefix:
# glob '{company}*.csv' would pull in other companies that share a name prefix
# ('project-b' would take 'project-b-test' files), and that would not show up.
INVENTORY_SUFFIXES   = (AD_FILE_SUFFIX, "-vkcloud", "-sbc-adv")
# Written by the pipeline itself — not inventory and not a lost source
GENERATED_CSV        = ("edr_coverage_report.csv", "edr_report.csv")
OUTPUT_CSV           = DATA_DIR / "edr_coverage_report.csv"
OUTPUT_JSON          = DATA_DIR / "edr_metrics.json"


# ---------------------------------------------------------------------------
# Normalisation helpers
# ---------------------------------------------------------------------------

def _norm_host(values: pd.Series) -> pd.Series:
    """
    Host-name match key: case does not matter, '_' is '-'.

    Underscore is allowed in a cloud VM name but not in a hostname per RFC 1123:
    cloud-init replaces it with a hyphen, and the EDR agent registers under the
    rewritten name ('ecs-corp-mfa_radius-az1-01' -> 'ecs-corp-mfa-radius-az1-01').
    Dots are left alone — FQDNs do not appear in any export
    (AD keeps the full name in a separate fqdn column).

    Apply to both sides of the join, or the rule will drift.
    """
    return values.astype(str).str.strip().str.upper().str.replace("_", "-", regex=False)


def _split_ips(value) -> list[str]:
    """
    Host addresses from the sourceip cell.

    Collectors write them as a comma-separated string, but historical VK Cloud
    exports store a Python list repr: "['10.0.2.19', '203.0.113.10']".
    """
    if value is None or (isinstance(value, float) and pd.isna(value)):
        return []
    text = str(value).strip().strip("[]")
    if not text or text.lower() == "nan":
        return []
    return [part.strip().strip("'\"") for part in text.split(",") if part.strip().strip("'\"")]


def _unique_ips(values: pd.Series) -> tuple[pd.Series, set[str]]:
    """
    Explode the address column into a Series (source-row index -> one address)
    and return it together with the set of addresses that occur exactly once.
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
    Manual mappings "host -> agent name": {company: {host: agent}}.

    Needed where the link exists but the data does not show it: a domain-joined
    Mac registers in EDR under a local name ('MacBook-Air-admin.local', '192'),
    and the domain name is in no API field. Guessing by username is not allowed —
    a second laptop of the same person would silently break the metric — so a
    human decides, and merge3 only suggests candidates in the log.

    Format:
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
    logger.info("Loaded aliases: %d mappings in %d companies",
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
    """Company from the inventory file name; None if the name does not match the scheme."""
    for suffix in INVENTORY_SUFFIXES:
        if path.stem.endswith(suffix):
            return path.stem[: -len(suffix)]
    return None


def discover_companies() -> dict[str, list[Path]]:
    """
    Find companies via *_edr.csv files and attach their inventory files.

    The company is defined by the agent export: without it there is nothing to
    compute coverage from, and a company with an empty agent pool must not be
    created — companies on a shared tenant would show 0% while live agents sat
    in another file.

    So inventory without an agent export is a warning, not a silent skip:
    four companies (project-g, project-h, project-i, project-j) stayed out of
    every metric for half a year that way. The fix is the EDR config, not
    code, but it must not be silent.
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
            "Inventory without an agent export: company '%s' (%s) will not appear in any "
            "metric — missing %s%s.csv. If its agents live in a shared tenant, add "
            "the company to the EDR config",
            company, ", ".join(f.name for f in inventory[company]), company, EDR_FILE_SUFFIX,
        )
    if unknown:
        logger.warning(
            "CSV files assigned to no company: %s — the name must end with %s",
            ", ".join(unknown), " / ".join(INVENTORY_SUFFIXES),
        )

    return result


# ---------------------------------------------------------------------------
# Data loading
# ---------------------------------------------------------------------------

def _first_non_empty(values: pd.Series):
    """First non-empty column value inside the group (otherwise the first)."""
    for value in values:
        if pd.notna(value) and str(value).strip() != "":
            return value
    return values.iloc[0] if len(values) else pd.NA


def _collapse_hosts(df: pd.DataFrame) -> pd.DataFrame:
    """
    One row per host: duplicates are merged, not dropped.

    A domain server appears in both AD and the cloud export. Dropping one of
    the rows would lose either sourceip (needed for IP matching) or dn (needed
    for OU exclusions). So: sourceip is unioned, dn/enabled come from the AD
    row, managed from the cloud row, source_type=server if the host is in the
    cloud (VDI is also counted as a server), and domain presence stays in
    in_ad. The grouping key is normalized: AD writes 'PROJ-B-…', cloud 'proj-b-…'.
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
    logger.info("  Duplicate hostnames merged: %d", len(df) - len(collapsed))
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
        # Type from the data: AD returns both servers and workstations and
        # distinguishes them with a column. Without the column — by file name,
        # as in older exports.
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
        # Keep all columns as-is, no allow-list: an allow-list twice silently
        # disabled logic (first the IP pass — because of a column name, then
        # lastuser hints — the column was simply left out of the list) and
        # bought nothing. This file is written here, there are about twenty
        # columns, and none of them enter the report — only inventory columns do.
        return df
    except Exception as e:
        logger.error("Cannot read %s: %s", fp.name, e)
        return pd.DataFrame()


# ---------------------------------------------------------------------------
# EDR matching
# ---------------------------------------------------------------------------

# An agent name of only digits and dots is not a machine identifier.
# macOS takes LocalHostName from the network name and cuts it at the first
# dot: a host named '192.168.1.15' registers in EDR as '192', and different
# machines collide under that name (export of 2026-08-12 — two laptops of
# different users). Those records are excluded from name matching.
_NUMERIC_AGENT_NAME = re.compile(r"^[\d.]+$")


def _agent_key(edr_df: pd.DataFrame) -> pd.Series:
    """
    Agent-record key: the name, and for truncated names — displayName.

    Three different Macs arrive under the same name '192', but in the console
    they are shown as 192.168.1.11 / .15 / .8 — that is their displayName.
    Using it as the key yields three distinct records instead of one collapsed
    one: dedup stops losing two of three, and aliases.yaml can point at a
    specific machine instead of "some 192". Matching on that key is still not
    allowed (it is an address, not a hostname) — _drop_unusable_agent_names
    will reject it.
    """
    key = _norm_host(edr_df[EDR_NAME_COL])
    if EDR_DISPLAYNAME_COL not in edr_df.columns:
        return key
    shown = _norm_host(edr_df[EDR_DISPLAYNAME_COL])
    truncated = key.str.match(_NUMERIC_AGENT_NAME) & shown.ne("") & shown.ne("NAN")
    return key.mask(truncated, shown)


def _drop_unusable_agent_names(edr_df: pd.DataFrame) -> pd.DataFrame:
    """Drop EDR records whose key cannot serve as a match key."""
    unusable = edr_df["_host"].str.match(_NUMERIC_AGENT_NAME)
    if unusable.any():
        logger.warning(
            "  EDR: %d records with a non-informative agent name (%s) — not matched by name, "
            "they can be referenced from aliases.yaml",
            int(unusable.sum()),
            ", ".join(sorted(set(edr_df.loc[unusable, "_host"]))[:5]),
        )
    return edr_df[~unusable]


def _sort_agents(edr_df: pd.DataFrame, has_online: bool, has_seen: bool) -> pd.DataFrame:
    """
    Agent records from most to least trustworthy: live first, and among equals
    the freshest registration. Every keep='first' below relies on this order,
    so it is set once and before all passes.
    """
    sort_cols = (["_online"] if has_online else []) + (["_seen"] if has_seen else [])
    return edr_df.sort_values(sort_cols, ascending=False, kind="mergesort") if sort_cols else edr_df


def _dedup_agents(edr_df: pd.DataFrame) -> pd.DataFrame:
    """
    One record per hostname.

    Reinstalling the agent creates a new EDR record with a different id: the
    old one is offline, the new one online. Without collapsing, the host would
    multiply in the report and inflate VM_TOTAL. Order is set in _sort_agents,
    so keep='first' is not "whichever came first" but "the live agent, and
    among equals the freshest registration".
    """
    dup_agents = int(edr_df.duplicated(subset=["_host"]).sum())
    if dup_agents:
        logger.info("  EDR: %d duplicate agent records collapsed", dup_agents)
    _warn_name_collisions(edr_df)
    return edr_df.drop_duplicates(subset=["_host"], keep="first")


def _warn_name_collisions(edr_df: pd.DataFrame) -> None:
    """
    Separate a reinstall from different machines under one name.

    Almost all duplicates are a re-registration of one machine: the agent is
    installed before domain join (domain=WORKGROUP, older version, empty
    sourceIP), then a second record appears; osname on those records matches.
    Different machines are given away by osname (checked 2026-08-12: of 22
    duplicate groups, 20 were a reinstall, 2 a collision: three Macs named
    '192' and two MACBOOK-AIR-ADMIN). Collapsing in that case hides a machine,
    so a warning is written — this is resolved in the EDR console, not in code.
    """
    if EDR_OSNAME_COL not in edr_df.columns:
        return
    dups = edr_df[edr_df.duplicated(subset=["_host"], keep=False)]
    collisions = []
    for name, group in dups.groupby("_host", sort=False):
        if group[EDR_OSNAME_COL].astype(str).nunique() <= 1:
            continue
        # displayName — how the machine is shown in the EDR console: for
        # truncated names this is the only way to tell which hosts are meant
        # ('192' is shown as 192.168.1.11 / .15 / .8)
        shown = (
            sorted(set(group[EDR_DISPLAYNAME_COL].astype(str)))
            if EDR_DISPLAYNAME_COL in group.columns else []
        )
        collisions.append(f"{name} ({', '.join(shown)})" if shown else name)
    if collisions:
        logger.warning(
            "  EDR: different machines under one name (OS differs): %s — "
            "coverage will keep one, resolve in the console",
            "; ".join(sorted(collisions)),
        )


def _name_usable(out: pd.DataFrame) -> pd.Series:
    """
    Whether this host can be matched by name. It cannot when the name is used
    by machines of different companies: there is one agent with that name and
    several hosts. The rule applies to all name-like keys (hostname,
    os_hostname, inv_hostname) — os_hostname of same-named VMs matches too.
    A manual alias still works: a human pointed at a specific agent.
    """
    if NAME_SHARED_COL not in out.columns:
        return pd.Series(True, index=out.index)
    return ~out[NAME_SHARED_COL].astype(bool)


def _claim_agent(out: pd.DataFrame, vm_idx, agent: pd.Series, how: str, has_online: bool,
                 claimed: set[str] | None = None) -> None:
    """Mark the host as covered by an agent found other than by the primary name."""
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
    The name matched but the addresses contradict — reason to doubt the match.

    Requiring address equality is not possible: 291 of 420 matched hosts have
    no address at all (AD does not store it), and the rule would cut two thirds
    of correct matches. Where the address is known on both sides, it matches
    in 129 of 129 cases — so a mismatch means different machines under one name.
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
                              f"(host {','.join(sorted(ours))} vs agent {','.join(sorted(theirs))})")
    if suspicious:
        logger.warning(
            "Name matched but addresses diverged for %d hosts — these may be different "
            "machines under one name: %s",
            len(suspicious), "; ".join(suspicious[:5]),
        )


def _match_by_alias(out: pd.DataFrame, by_name: pd.DataFrame, aliases: dict,
                    has_online: bool, claimed: set[str]) -> int:
    """
    Pass over manual mappings from aliases.yaml.

    Complements name matching rather than overriding it: applied only to hosts
    that did not match on their own. A mapping to a missing agent is a warning,
    not a silent miss: the agent was likely reinstalled and the file entry is stale.
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
        # the agent key went into the index here, so it is marked separately
        _claim_agent(out, vm_idx, agents.loc[target], "alias", has_online)
        claimed.add(target)
        matched += 1
    if stale:
        logger.warning("  aliases.yaml: agent not found in the export: %s", "; ".join(stale))
    return matched


def _suggest_aliases(out: pd.DataFrame, edr_df: pd.DataFrame) -> None:
    """
    Suggest aliases.yaml candidates from the username.

    A workstation is often named after the owner ('m-user-a', 'm-proj-c-00020'),
    while the agent keeps lastuser ('a.user', 'proj-c-00020'). That is the link,
    but it is heuristic, so it is not applied automatically: the hint goes to
    the log, the decision and the file write stay with a human. Only unambiguous
    pairs are shown.
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
        logger.info("  aliases.yaml candidates (user matched, check in the console): %s",
                    "; ".join(sorted(hints)))


def _match_by_inventory_hostname(out: pd.DataFrame, edr_df: pd.DataFrame,
                                 has_online: bool, claimed: set[str]) -> int:
    """
    Pass over the name the agent reports about itself (inventory.hostname).

    Filled only on enriched records — those whose name in the agent list
    identifies nothing. This is where domain-joined Macs come back: an agent
    named '192' is called m-proj-c-00026 in inventory, and that host is in AD.
    Search the full record set, not the collapsed one: three agents named
    '192' have different restored names, and name-dedup would keep only one.

    Mutates out in place, returns the number of additionally matched hosts.
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
    # inventory name equals the agent name — no new information;
    # an agent already taken by its host is not reused
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
    Intermediate pass: by in-guest hostname (os_hostname column).

    Present only in SberCloud exports: VK Cloud's highest Nova microversion is
    2.42, and the field appears in 2.90. This is an **additional** key, not a
    replacement of the VM name: os_hostname is fixed at create and does not
    follow instance rename, so on some VMs it points at another name
    (checked 2026-08-12: 19 mismatches of 172, 13 of them not about characters).
    Hence the guard: an agent already taken by a hostname match is not reused
    via the second key — otherwise pairs like proj-b-prod-lb-1 /
    proj-b-prod-vault-lb-1, where EDR has agents under both names, would false-match.

    Mutates out in place, returns the number of additionally matched hosts.
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
    Second pass: match by IP for hosts not found by name.

    sourceip in the EDR export is the address the agent connected from (NAT/VIP),
    not a machine identifier: 36 addresses cover 88 different hosts. So an
    address is a usable key only if unique on both sides; ambiguous ones are
    dropped entirely, not "first one wins". Servers only: workstations get
    DHCP, and the address in the AD export goes stale.

    Mutates out in place, returns the number of additionally matched hosts.
    """
    if VM_SOURCEIP_COL not in out.columns or EDR_IP_COL not in edr_df.columns:
        return 0

    candidates = out.index[~out["has_edr"] & (out[SOURCE_TYPE_COL] == "server")]
    if candidates.empty:
        return 0

    # Uniqueness on the VM side is computed over all company rows, not just
    # candidates: an address shared with an already-matched host is also ambiguous.
    vm_ips, vm_unique = _unique_ips(out[VM_SOURCEIP_COL])
    edr_ips, edr_unique = _unique_ips(edr_df[EDR_IP_COL])
    usable = vm_unique & edr_unique
    shared = set(vm_ips) & set(edr_ips)
    if shared:
        logger.info(
            "  IP pass: addresses shared with EDR: %d, of which usable (unique on both sides): %d",
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
            continue  # no usable address, or different agents — do not guess
        _claim_agent(out, vm_idx, edr_df.loc[hits.pop()], "ip", has_online, claimed)
        matched += 1
    return matched


def _merge_with_edr(vm_df: pd.DataFrame, edr_df: pd.DataFrame,
                    aliases: dict | None = None) -> pd.DataFrame:
    """
    Join vm_df with edr_df in five passes, from the most reliable key down:
      1. hostname (case-insensitive, '_' == '-');
      2. manual mappings from aliases.yaml;
      3. inv_hostname — the name the agent reports about itself;
      4. os_hostname from the cloud export (SberCloud only);
      5. IP — servers only, and only addresses unique on both sides.
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
        # unix time of last agent contact (UTC) — for the silence window
        edr_df["_seen_ts"] = seen.apply(lambda t: t.timestamp() if pd.notna(t) else float("nan"))

    # Name passes use collapsed records with a usable name; address uniqueness
    # needs every record, including dropped ones, or a foreign address can look unique.
    edr_df = _sort_agents(edr_df, has_online, has_seen)
    # by_any — all records collapsed by name: aliases.yaml refers to them, and
    # that is why truncated names like '192' need it. by_name — the same minus
    # names that do not identify a machine: only those are matched automatically.
    by_any = _dedup_agents(edr_df)
    by_name = _drop_unusable_agent_names(by_any)

    out = vm_df.copy()
    out["_host"] = _norm_host(out[VM_HOSTNAME_COL])

    # Pass 1: hostname. Hosts whose name is used by other companies are skipped:
    # the name is no longer a key; IP, alias, and os_hostname remain.
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
    # Agents claimed by at least one host. Needed to tell
    # "agent exists, inventory missing" from ordinary non-coverage.
    claimed: set[str] = set(out.loc[out["has_edr"], "_host"])

    _warn_ip_contradicts_name(out, edr_df)

    # Pass 2: manual mappings (a human knows what the data does not show)
    matched_by_alias = _match_by_alias(out, by_any, aliases or {}, has_online, claimed)

    # Pass 3: name the agent reports about itself (enrichment from /agents/{id})
    matched_by_inv = _match_by_inventory_hostname(out, edr_df, has_online, claimed)

    # Pass 4: in-guest hostname (SberCloud only)
    matched_by_os = _match_by_os_hostname(out, by_name, has_online, claimed)

    # Pass 5: IP (servers only, unambiguous addresses only)
    matched_by_ip = _match_by_ip(out, edr_df, has_online, claimed)

    out.loc[~out["has_edr"], "edr_last_seen"] = float("nan")

    logger.info(
        "  Matched by hostname: %d, additionally by alias: %d, by inv_hostname: %d, "
        "by os_hostname: %d, by IP: %d",
        matched_by_host, matched_by_alias, matched_by_inv, matched_by_os, matched_by_ip,
    )
    _suggest_aliases(out, edr_df)

    # Expose the agent pool and those of them that found their host: a single
    # company cannot be judged — companies on a shared tenant share one _edr.csv,
    # and foreign agents would look ownerless. build_report folds this.
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

    # A server enters the pool if it has an address (cloud export) or it is
    # domain-joined and the account is enabled. Requiring an address from all
    # would be a leftover from when servers came only from clouds: AD stores
    # no addresses, and 104 domain servers would silently drop from the denominator.
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
    A host belongs to exactly one company. Resolve cases where sources disagreed.

    The cloud export beats the domain one: the VM lives in a specific company
    account, that is a fact, while in AD a host is assigned by OU, patterns, or
    even `default_company`. So the AD row moves to the company that has a cloud
    row for the same host and is merged with it (that is how `dependencytrack`
    and `teleport-db` were counted as project-a though they are project-c VMs).

    If several cloud rows exist for different companies — these are **different
    machines with the same name** (`lb-waf-prod-01` at project-b and project-c:
    different addresses, different projects). They must not be merged, and must
    not be matched by name either: the EDR tenant is shared, there is one agent
    with that name, and both machines were marked covered — one of them by a
    foreign agent. Such hosts are tagged `name_shared`, and the name pass skips
    them; IP, alias, and os_hostname remain.
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
        logger.info("  Rows moved to the cloud-VM owner: %d", moved)
    if shared:
        logger.warning(
            "Same name on machines of different companies: %s — these are different hosts, "
            "not matched by name (the agent with that name would go to both)",
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
    Agents not matched to any host — a signal of a lost source.

    Counted per tenant, not per company: companies on a shared tenant share one
    `_edr.csv`, and a neighbour company's agent would otherwise look ownerless
    (project-b would "lose" almost all 452 records). The number itself fixes
    nothing, but it is the only outward signal when inventory is missing
    entirely: behind it sit a VDI pool, another cloud tenant, an office
    segment, and a hypervisor that cannot be collected.
    """
    for agents, tenant in tenants.items():
        orphans = sorted(agents - tenant["claimed"])
        for company in tenant["companies"]:
            company_metrics[company]["AGENTS_WITHOUT_INVENTORY"] = len(orphans)
        if orphans:
            logger.warning(
                "Agents without a host in inventory: %d of %d (companies: %s). Examples: %s",
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

    # Read every company's inventory before analysis: who owns a host is only
    # visible as a whole — one company's cloud export overrides another's AD.
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
        # Identify the tenant by the agent pool itself: companies of one tenant
        # fetch the list in one request and get a byte-identical _edr.csv.
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
    # Per tenant, not a sum over companies: companies on a shared tenant share
    # this number, and adding would count the same agents four times.
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
