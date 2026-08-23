"""
Export domain hosts from Active Directory via LDAP/LDAPS.
Reads ad_config.yaml and writes {company}-ad.csv for each company entry.
Output is automatically picked up by merge3.py for EDR coverage analysis.

Both workstations and servers are exported: OUs are listed in `workstation_ous`
and `server_ous`, and the type goes into the source_type column. The directory
has no separate "this is a server" attribute (checked 2026-08-16: a regular
server and a laptop share userAccountControl=0x1000 and the same SPNs), so the
type is an organizational choice — the OU list — and `operatingSystem` is a
check. Only domain controllers are identified from the directory alone:
primaryGroupID=516.

Each OU is read exactly once, even if several companies list it, and hosts are
assigned to companies after the read — so a host that matches nobody's patterns
goes to `default_company` instead of vanishing silently.
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

# Config from EDR_CONFIG_DIR (in the container a read-only secrets directory
# rendered by ansible from SOPS); output goes to EDR_DATA_DIR. Both default
# to the current directory for a manual laptop run.
CONFIG_DIR = Path(os.environ.get("EDR_CONFIG_DIR", "."))
DATA_DIR = Path(os.environ.get("EDR_DATA_DIR", "."))
CONFIG_PATH = CONFIG_DIR / "ad_config.yaml"

# userAccountControl bit 1 (0x2) — account is disabled
UAC_DISABLED_BIT = 0x2
# Domain controllers: the only type the directory reports unambiguously
DC_PRIMARY_GROUP = 516

# Type hint from operatingSystem. Used when the OU is marked source_type: auto,
# and to compare declared type with the actual OS — mismatches go to the log.
OS_MATCHERS = {
    # client Windows: "Server" in the name excludes it
    "windows": lambda os_name: os_name.lower().startswith("windows") and "server" not in os_name.lower(),
    "macos":   lambda os_name: os_name.lower().startswith("macos"),
    # substring, not prefix: some Linux machines report 'pc-linux-gnu'
    "linux":   lambda os_name: "linux" in os_name.lower(),
    "server":  lambda os_name: "server" in os_name.lower() or "linux" in os_name.lower(),
    # any non-empty OS: service accounts have it empty
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

# gMSAs inherit from the computer class and would otherwise appear as machines
BASE_FILTER = "(&(objectClass=computer)(!(objectClass=msDS-GroupManagedServiceAccount)){extra})"


def load_config(config_path: str = CONFIG_PATH) -> list[dict]:
    path = Path(config_path)
    if not path.exists():
        raise FileNotFoundError(f"Config file not found: {path.resolve()}")
    with path.open("r", encoding="utf-8") as f:
        data = yaml.safe_load(f)
    return data["companies"]


def build_ldap_filter(enabled_only: bool) -> str:
    """Search filter. OS filtering happens after the read — one OU is read
    once for everyone, and companies have different os_filter values."""
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
    # Name from dNSHostName: on Linux servers cn is truncated to 15 characters
    # (NetBIOS), so 'PROJ-B-DEMO-CERTM' would not match 'proj-b-demo-certmanager'
    # from the cloud.
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
# Assign hosts to companies
# ---------------------------------------------------------------------------

def ou_entries(company: dict) -> list[tuple[str, str]]:
    """
    Company OUs as (dn, declared type). A list item is either a DN string
    or {dn: ..., source_type: server|workstation|auto}.
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
    Host type: the type declared in the config, except domain controllers —
    they are always servers. 'auto' derives the type from operatingSystem.
    """
    if host["is_dc"]:
        return "server"
    if declared != "auto":
        return declared
    return "server" if OS_MATCHERS["server"](host["os"]) else "workstation"


def os_allowed(host: dict, source_type: str, company: dict) -> bool:
    """Whether the host passes the OS filter: workstations use the company
    os_filter; servers accept any non-empty OS (otherwise objects without OS
    would enter the export)."""
    key = company.get("os_filter", "windows") if source_type == "workstation" \
        else company.get("server_os_filter", "any")
    return OS_MATCHERS.get(key, OS_MATCHERS["all"])(host["os"])


def _matches_any(hostname_upper: str, patterns_upper: list[str]) -> bool:
    return any(fnmatch.fnmatch(hostname_upper, p) for p in patterns_upper)


CLAIMS_ALL = "all"


def patterns_of(company: dict, source_type: str) -> list[str] | str:
    """
    Company patterns for this host type: a list or CLAIMS_ALL.

    `all` is an explicit mark "take everything left in my OUs". An empty list
    means the same implicitly, so it is warned about: the silent "empty = all"
    once let project-a scoop 30 project-b servers.
    """
    key = "hostname_patterns" if source_type == "workstation" else "server_hostname_patterns"
    value = company.get(key)
    if isinstance(value, str):
        return CLAIMS_ALL if value.strip().lower() == CLAIMS_ALL else [value]
    return list(value) if value else CLAIMS_ALL


def company_claims(company: dict, host: dict, source_type: str) -> bool:
    """Whether the company claims this host (honouring exclude patterns)."""
    name = host["hostname"].upper()
    include = patterns_of(company, source_type)
    exclude = [p.upper() for p in (company.get("hostname_exclude_patterns") or [])]
    if include != CLAIMS_ALL and not _matches_any(name, [p.upper() for p in include]):
        return False
    return not _matches_any(name, exclude)


def _deduplicate_nested_ous(hosts_by_ou: dict[str, list[dict]]) -> dict[str, list[dict]]:
    """
    One host — one OU: the most specific of those that returned it.

    OUs nest (`OU=MacOS,OU=Laptops,OU=Assets` inside `OU=Laptops,OU=Assets`),
    and the search is SUBTREE, so the same machine arrives under two keys.
    Assigning them independently would give the host twice: under `OU=MacOS`
    project-e takes it with `m-*`, and under `OU=Laptops` it matches nobody
    and goes to `default_company`. That is how `m-user-c` ended up in both
    project-a and project-e, and twice in coverage.

    The deepest OU is chosen because it is the most precise admin hint: if
    a nested OU was listed separately, that is the intended one.
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
    Assign hosts to companies. Returns (company -> rows, unassigned).

    Only companies that list this OU in the config may claim. If nobody takes
    the host, it goes to the company with `default_company: true`; if that is
    also missing, it enters the unassigned list: it must not vanish silently —
    that already cost four companies half a year of missing metrics.
    """
    claimed: dict[str, list[dict]] = {c["name"]: [] for c in companies}
    unassigned: list[dict] = []
    default = next((c for c in companies if c.get("default_company")), None)

    for ou, hosts in _deduplicate_nested_ous(hosts_by_ou).items():
        owners = [(c, declared) for c in companies
                  for dn, declared in ou_entries(c) if dn.upper() == ou.upper()]
        for host in hosts:
            row, taken = None, None
            # Companies with explicit patterns first, then "take-all": config
            # order must not decide. Otherwise a pattern-less company listed
            # first scoops other hosts from a shared OU — that is how project-a
            # took 30 project-b servers, and totals never showed it.
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
    Checks that catch an ambiguous config before it silently drifts.

    There is exactly one error: two "take-all" claimants for one OU and one
    host type. Who gets the host then cannot be inferred from the config, and
    line order used to decide. The rest are warnings: implicit "empty = all"
    works, but must be written as a word (`claims` patterns: `all`).
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
                    f"OU {ou}: several companies claim everything ({', '.join(greedy)}) "
                    f"for type '{source_type}'. Set patterns or exclude — the config "
                    f"does not say whose host this is"
                )
    for company in companies:
        for source_type, ou_key in (("workstation", "workstation_ous"), ("server", "server_ous")):
            if company.get(ou_key) and patterns_of(company, source_type) == CLAIMS_ALL \
                    and not isinstance(company.get(
                        "hostname_patterns" if source_type == "workstation"
                        else "server_hostname_patterns"), str):
                logger.warning(
                    "Company '%s': patterns for '%s' are not set — takes everything from its OUs. "
                    "Write this explicitly: %s: all",
                    company["name"], source_type,
                    "hostname_patterns" if source_type == "workstation" else "server_hostname_patterns",
                )
    return problems


def check_empty_result(company: dict, rows: list[dict]) -> None:
    """
    The company declared OUs but received no hosts from them.

    That is the missing signal: project-b with five server OUs logged
    `saved 14 hosts {'workstation': 14}` — zero servers and no warning,
    while overall coverage looked healthy.
    """
    kinds = {row["source_type"] for row in rows}
    for source_type, ou_key in (("workstation", "workstation_ous"), ("server", "server_ous")):
        if company.get(ou_key) and source_type not in kinds:
            logger.warning(
                "Company '%s': %d %s set, but 0 hosts of type '%s' received — "
                "check patterns: another company may have claimed them",
                company["name"], len(company[ou_key]), ou_key, source_type,
            )


def check_declared_type(rows: list[dict], company: str) -> None:
    """Compare the config type with the actual OS — mismatches are shown, not
    silently fixed: the OU is an admin decision, the OS is a fact from the machine."""
    for row in rows:
        if not row["os"]:
            continue
        looks_server = OS_MATCHERS["server"](row["os"])
        if looks_server and row["source_type"] == "workstation":
            logger.warning("  %s: %s is marked as a workstation, but the OS is server (%s)",
                           company, row["hostname"], row["os"])
        elif not looks_server and row["source_type"] == "server" and not row["is_dc"]:
            logger.warning("  %s: %s is marked as a server, but the OS is client (%s)",
                           company, row["hostname"], row["os"])


def main() -> None:
    companies = load_config(CONFIG_PATH)
    if not companies:
        logger.error("No companies in the config")
        sys.exit(1)

    problems = validate_config(companies)
    for problem in problems:
        logger.error("Config: %s", problem)
    if problems:
        # Better to export nothing than to export wrongly: previous CSVs
        # stay in place, and the exporter marks the section as failed.
        sys.exit(1)

    # Each OU is read once, even if several companies list it:
    # the shared OU=Laptops used to be re-read once per company.
    wanted: dict[str, dict] = {}
    for company in companies:
        for dn, _ in ou_entries(company):
            wanted.setdefault(dn, company)

    first = companies[0]
    ldap_filter = build_ldap_filter(first.get("enabled_only", True))
    logger.info("Reading %d OUs, filter: %s", len(wanted), ldap_filter)
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
            "Hosts claimed by no company: %d — they will not appear in metrics. "
            "Set patterns or default_company. Examples: %s",
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
            logger.info("  %s: collapsed duplicate hostnames: %d", company["name"], before - len(df))
        df["company"] = company["name"]
        out_path = DATA_DIR / f"{company['name']}-ad.csv"
        df.to_csv(out_path, index=False, encoding="utf-8")
        counts = df["source_type"].value_counts().to_dict()
        logger.info("Company '%s': saved %d hosts %s → %s",
                    company["name"], len(df), counts, out_path)


if __name__ == "__main__":
    main()
