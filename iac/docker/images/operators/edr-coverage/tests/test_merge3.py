"""
Tests for matching hosts to EDR agents.

Not metric arithmetic — the matching rules that already broke silently:
names, duplicates, and IP-pass limits. Rationale for each rule lives in
merge3 comments; this file only checks the behaviour.
"""
import logging

import pandas as pd
import pytest

import merge3


def _vm(**over) -> dict:
    row = {
        "hostname": "host-01", "sourceip": "10.0.0.1", "managed": "", "company": "x",
        "source_type": "server", "in_ad": False, "excluded": False,
    }
    row.update(over)
    return row


def _agent(**over) -> dict:
    row = {
        "name": "HOST-01", "displayname": "host-01.corp.example.com",
        "osname": "Ubuntu 24.04.4 LTS", "isonline": "True", "lastuser": "CGTEAM\\admin",
        "sourceip": "10.0.0.1", "lastseenat": "2026-08-12 10:00:00",
    }
    row.update(over)
    return row


# ---------------------------------------------------------------------------
# Normalisation
# ---------------------------------------------------------------------------

def test_norm_host_ignores_case_and_underscore():
    # cloud-init replaces '_' with '-', the agent registers under the rewritten name
    got = merge3._norm_host(pd.Series(["ecs-corp-mfa_radius-az1-01", " Proj-b-01 "]))
    assert list(got) == ["ECS-CORP-MFA-RADIUS-AZ1-01", "PROJ-B-01"]


def test_norm_host_keeps_dots():
    # no export has dots in names, so the domain does not need to be stripped
    assert merge3._norm_host(pd.Series(["web-01.corp.ru"]))[0] == "WEB-01.CORP.RU"


@pytest.mark.parametrize("value, expected", [
    ("10.0.1.5,10.0.1.6", ["10.0.1.5", "10.0.1.6"]),
    ("['10.0.2.19', '203.0.113.10']", ["10.0.2.19", "203.0.113.10"]),  # old cloud exports
    ("10.0.1.5", ["10.0.1.5"]),
    ("", []),
    (float("nan"), []),
    (None, []),
])
def test_split_ips(value, expected):
    assert merge3._split_ips(value) == expected


# ---------------------------------------------------------------------------
# Merging hosts from different exports
# ---------------------------------------------------------------------------

def test_collapse_merges_ad_and_cloud_rows():
    df = pd.DataFrame([
        _vm(hostname="ecs-corp-mfa_radius-az1-01", sourceip="10.0.1.5,10.0.1.6",
            enabled=None, dn=None),
        _vm(hostname="ECS-CORP-MFA-RADIUS-AZ1-01", sourceip="['10.0.1.5', '192.168.1.9']",
            source_type="workstation", in_ad=True, enabled="True", dn="OU=Servers,DC=corp"),
        _vm(hostname="lonely-01", managed="kubernetes", enabled=None, dn=None),
    ])
    out = merge3._collapse_hosts(df)

    assert len(out) == 2, "a host from two exports must become one row"
    merged = out.iloc[0]
    assert merged["source_type"] == "server", "the host is in the cloud — so it is a server"
    assert bool(merged["in_ad"]) is True, "domain presence is not lost"
    assert merged["dn"] == "OU=Servers,DC=corp", "OU is needed for exclusions"
    assert merged["enabled"] == "True"
    assert merged["sourceip"] == "10.0.1.5,10.0.1.6,192.168.1.9", "addresses are unioned without duplicates"
    assert out.iloc[1]["managed"] == "kubernetes"


def test_collapse_is_noop_without_duplicates():
    df = pd.DataFrame([_vm(hostname="a-01"), _vm(hostname="b-01")])
    assert merge3._collapse_hosts(df).equals(df)


# ---------------------------------------------------------------------------
# Agent dedup
# ---------------------------------------------------------------------------

def test_dedup_picks_online_then_freshest():
    vm = pd.DataFrame([_vm(hostname="w-0016")])
    edr = pd.DataFrame([
        _agent(name="W-0016", isonline="False", lastseenat="2026-07-20 10:00:00"),
        _agent(name="W-0016", isonline="True", lastseenat="2026-08-12 10:00:00"),
    ])
    out = merge3._merge_with_edr(vm, edr)
    assert len(out) == 1, "agent duplicates must not multiply the host"
    assert bool(out.iloc[0]["edr_online"]) is True


def test_dedup_between_two_offline_takes_freshest():
    # both agent-records offline: the pick must be deterministic, not 'first in the file'
    vm = pd.DataFrame([_vm(hostname="w-00178")])
    edr = pd.DataFrame([
        _agent(name="W-00178", isonline="False", lastseenat="2026-06-22 07:53:00"),
        _agent(name="W-00178", isonline="False", lastseenat="2026-06-22 08:47:00"),
    ])
    last_seen = merge3._merge_with_edr(vm, edr).iloc[0]["edr_last_seen"]
    assert last_seen == pd.Timestamp("2026-06-22 08:47:00", tz="UTC").timestamp()


def test_numeric_agent_name_is_not_a_key(caplog):
    # macOS cuts the network name at the first dot: three different Macs arrive as '192'
    vm = pd.DataFrame([_vm(hostname="192", sourceip="10.9.9.9")])
    edr = pd.DataFrame([_agent(name="192", displayname="192.168.1.15", sourceip="192.168.1.15")])
    out = merge3._merge_with_edr(vm, edr)
    assert not out.iloc[0]["has_edr"]
    assert "non-informative agent name" in caplog.text


def test_name_collision_warns_with_display_name(caplog):
    vm = pd.DataFrame([_vm(hostname="macbook-air-admin", source_type="workstation")])
    edr = pd.DataFrame([
        _agent(name="MACBOOK-AIR-ADMIN", displayname="MacBook-Air-UserA.local",
               osname="macOS 15.6", sourceip="10.10.17.93"),
        _agent(name="MACBOOK-AIR-ADMIN", displayname="MacBook-Air-UserB.local",
               osname="macOS 26.5.2", isonline="False", sourceip="10.10.8.14"),
    ])
    merge3._merge_with_edr(vm, edr)
    assert "different machines" in caplog.text
    assert "MacBook-Air-UserA.local" in caplog.text, "need the name under which the machine is shown in the console"


# ---------------------------------------------------------------------------
# Manual mappings (aliases.yaml)
# ---------------------------------------------------------------------------

def test_alias_matches_mac_registered_under_local_name():
    # key of a truncated record is its displayName; the alias points at it
    vm = pd.DataFrame([_vm(hostname="m-user-b", source_type="workstation", in_ad=True)])
    edr = pd.DataFrame([_agent(name="192", displayname="192.168.1.15",
                               osname="macOS 26.6.1", lastuser="b.user")])
    out = merge3._merge_with_edr(vm, edr, {"M-USER-B": "192.168.1.15"}).iloc[0]
    assert out["has_edr"] and out["matched_by"] == "alias"


def test_truncated_names_stay_distinct_by_display_name():
    # three different Macs named '192' must not collapse into one record,
    # or the alias would bind the host to an arbitrary one of them
    vm = pd.DataFrame([
        _vm(hostname="m-user-b", source_type="workstation"),
        _vm(hostname="m-user-a", source_type="workstation"),
    ])
    edr = pd.DataFrame([
        _agent(name="192", displayname="192.168.1.15", lastuser="b.user", isonline="False"),
        _agent(name="192", displayname="192.168.1.11", lastuser="a.user", isonline="True"),
        _agent(name="192", displayname="192.168.1.8", lastuser="root", isonline="False"),
    ])
    aliases = {"M-USER-B": "192.168.1.15", "M-USER-A": "192.168.1.11"}
    out = merge3._merge_with_edr(vm, edr, aliases).set_index("hostname")
    assert list(out["matched_by"]) == ["alias", "alias"]
    # each host got its own agent, not 'whichever 192 came first'
    assert bool(out.at["m-user-b", "edr_online"]) is False
    assert bool(out.at["m-user-a", "edr_online"]) is True


def test_alias_does_not_override_own_hostname_match():
    # the mapping complements name matching, it does not override it
    vm = pd.DataFrame([_vm(hostname="host-01")])
    edr = pd.DataFrame([_agent(name="HOST-01"), _agent(name="OTHER", sourceip="10.9.9.9")])
    out = merge3._merge_with_edr(vm, edr, {"HOST-01": "OTHER"}).iloc[0]
    assert out["matched_by"] == "hostname"


def test_alias_to_missing_agent_warns(caplog):
    vm = pd.DataFrame([_vm(hostname="m-gone", source_type="workstation")])
    edr = pd.DataFrame([_agent()])
    out = merge3._merge_with_edr(vm, edr, {"M-GONE": "AGENT-THAT-LEFT"}).iloc[0]
    assert not out["has_edr"]
    assert "agent not found" in caplog.text


def test_alias_candidates_are_suggested_not_applied(caplog):
    # hostname matches the lastuser login — a hint, not a match
    caplog.set_level(logging.INFO)
    vm = pd.DataFrame([_vm(hostname="m-user-a", source_type="workstation", in_ad=True)])
    edr = pd.DataFrame([_agent(name="MAC", displayname="Mac.loc", lastuser="a.user")])
    out = merge3._merge_with_edr(vm, edr).iloc[0]
    assert not out["has_edr"], "a username heuristic must not enter the metric"
    assert "aliases.yaml candidates" in caplog.text
    assert "m-user-a -> MAC" in caplog.text


def test_alias_candidate_hidden_when_user_owns_two_machines(caplog):
    caplog.set_level(logging.INFO)
    vm = pd.DataFrame([
        _vm(hostname="m-user-a", source_type="workstation"),
        _vm(hostname="m-user-a-2", source_type="workstation"),
    ])
    edr = pd.DataFrame([_agent(name="MAC-A", lastuser="a.user"),
                        _agent(name="MAC-B", lastuser="a.user")])
    merge3._merge_with_edr(vm, edr)
    assert "aliases.yaml candidates" not in caplog.text


# ---------------------------------------------------------------------------
# inventory.hostname pass (enrichment from /agents/{id})
# ---------------------------------------------------------------------------

def test_inventory_hostname_recovers_truncated_mac_name():
    # an agent named '192' is called by its domain name in inventory
    vm = pd.DataFrame([_vm(hostname="m-proj-c-00026", source_type="workstation", in_ad=True)])
    edr = pd.DataFrame([_agent(name="192", displayname="192.168.1.11",
                               inv_hostname="m-proj-c-00026", osname="macOS 26.4.1")])
    out = merge3._merge_with_edr(vm, edr).iloc[0]
    assert out["has_edr"] and out["matched_by"] == "inv_hostname"


def test_inventory_hostname_keeps_all_records_of_one_name():
    # three Macs arrive as '192': name-dedup would keep one inventory name
    vm = pd.DataFrame([
        _vm(hostname="m-proj-c-00026", source_type="workstation", in_ad=True),
        _vm(hostname="m-proj-c-00012", source_type="workstation", in_ad=True),
    ])
    edr = pd.DataFrame([
        _agent(name="192", displayname="192.168.1.11", inv_hostname="m-proj-c-00026"),
        _agent(name="192", displayname="192.168.1.15", inv_hostname="m-proj-c-00012"),
    ])
    out = merge3._merge_with_edr(vm, edr)
    assert list(out["matched_by"]) == ["inv_hostname", "inv_hostname"]


def test_inventory_hostname_does_not_steal_claimed_agent():
    vm = pd.DataFrame([
        _vm(hostname="host-01"),
        _vm(hostname="other-01", sourceip="10.0.0.9"),
    ])
    # agent host-01 inventory reports a foreign name other-01, but it is already claimed
    edr = pd.DataFrame([_agent(name="HOST-01", inv_hostname="other-01")])
    out = merge3._merge_with_edr(vm, edr).set_index("hostname")
    assert out.at["host-01", "matched_by"] == "hostname"
    assert not out.at["other-01", "has_edr"]


# ---------------------------------------------------------------------------
# os_hostname pass
# ---------------------------------------------------------------------------

def test_os_hostname_matches_when_name_does_not():
    vm = pd.DataFrame([_vm(hostname="gitdev01", os_hostname="git_dev")])
    edr = pd.DataFrame([_agent(name="git-dev")])
    out = merge3._merge_with_edr(vm, edr).iloc[0]
    assert out["has_edr"] and out["matched_by"] == "os_hostname"


def test_os_hostname_does_not_steal_claimed_agent():
    # os_hostname is fixed at VM create: on proj-b-prod-lb-1 it points at
    # a foreign name that already has its own EDR agent
    vm = pd.DataFrame([
        _vm(hostname="proj-b-prod-lb-1", os_hostname="proj-b-prod-vault-lb-1", sourceip="10.0.0.2"),
        _vm(hostname="proj-b-prod-vault-lb-1", os_hostname="proj-b-prod-vault-lb-1", sourceip="10.0.0.3"),
    ])
    edr = pd.DataFrame([_agent(name="PROJ-B-PROD-VAULT-LB-1", sourceip="10.9.9.2")])
    out = merge3._merge_with_edr(vm, edr).set_index("hostname")
    assert out.at["proj-b-prod-vault-lb-1", "matched_by"] == "hostname"
    assert not out.at["proj-b-prod-lb-1", "has_edr"], "the agent is already claimed by its host"


# ---------------------------------------------------------------------------
# IP pass
# ---------------------------------------------------------------------------

def test_ip_pass_matches_unique_address():
    vm = pd.DataFrame([_vm(hostname="selenoid-01", sourceip="10.0.6.58")])
    edr = pd.DataFrame([_agent(name="TEST-QA-SELENOID", sourceip="10.0.6.58")])
    out = merge3._merge_with_edr(vm, edr).iloc[0]
    assert out["has_edr"] and out["matched_by"] == "ip"
    assert not pd.isna(out["edr_last_seen"]), "an IP match also enters the silence window"


def test_ip_pass_skips_address_shared_by_several_agents():
    # sourceip in EDR is the connect address (NAT/VIP): two different hosts report 10.0.16.5
    vm = pd.DataFrame([_vm(hostname="unknown-01", sourceip="10.0.16.5")])
    edr = pd.DataFrame([
        _agent(name="PROJ-B-PROD-LB-1", sourceip="10.0.16.5"),
        _agent(name="PROJ-B-PROD-VAULT-LB-1", sourceip="10.0.16.5"),
    ])
    assert not merge3._merge_with_edr(vm, edr).iloc[0]["has_edr"]


def test_ip_pass_skips_address_shared_by_several_hosts():
    vm = pd.DataFrame([
        _vm(hostname="lb-a", sourceip="10.0.16.5"),
        _vm(hostname="lb-b", sourceip="10.0.16.5"),
    ])
    edr = pd.DataFrame([_agent(name="SOME-AGENT", sourceip="10.0.16.5")])
    assert not merge3._merge_with_edr(vm, edr)["has_edr"].any()


def test_ip_pass_ignores_workstations():
    # workstations get DHCP; the address in the AD export goes stale
    vm = pd.DataFrame([_vm(hostname="w-00001", sourceip="192.168.139.5",
                           source_type="workstation", in_ad=True)])
    edr = pd.DataFrame([_agent(name="SOMEONE-ELSE", sourceip="192.168.139.5")])
    assert not merge3._merge_with_edr(vm, edr).iloc[0]["has_edr"]


# ---------------------------------------------------------------------------
# Lost source: inventory without agents and agents without inventory
# ---------------------------------------------------------------------------

def _ad_row(**over) -> dict:
    """A row as active-directory.py writes it: AD does not store addresses."""
    row = {"hostname": "w-proj-a-00001", "sourceip": "", "enabled": "True",
           "dn": "OU=Laptops,DC=corp", "source_type": "workstation"}
    row.update(over)
    return row


def _write(path, rows: list[dict]) -> None:
    pd.DataFrame(rows).to_csv(path, index=False)


def test_inventory_without_agent_export_warns(tmp_path, monkeypatch, caplog):
    # project-g and three more companies stayed out of every metric for half a year that way
    caplog.set_level(logging.INFO)
    monkeypatch.setattr(merge3, "DATA_DIR", tmp_path)
    _write(tmp_path / "project-b_edr.csv", [_agent()])
    _write(tmp_path / "project-b-ad.csv", [_ad_row()])
    _write(tmp_path / "project-g-ad.csv", [_ad_row(hostname="ard-01")])

    found = merge3.discover_companies()

    assert set(found) == {"project-b"}, "a company without an agent export must not be created"
    assert "Inventory without an agent export" in caplog.text
    assert "project-g" in caplog.text


def test_similar_company_names_do_not_steal_files(tmp_path, monkeypatch):
    # glob '{company}*.csv' would give project-b-test files to company project-b
    monkeypatch.setattr(merge3, "DATA_DIR", tmp_path)
    for company in ("project-b", "project-b-test"):
        _write(tmp_path / f"{company}_edr.csv", [_agent()])
        _write(tmp_path / f"{company}-ad.csv", [_ad_row()])

    found = merge3.discover_companies()

    assert [f.name for f in found["project-b"]] == ["project-b-ad.csv"]
    assert [f.name for f in found["project-b-test"]] == ["project-b-test-ad.csv"]


def test_unrecognised_csv_is_reported(tmp_path, monkeypatch, caplog):
    caplog.set_level(logging.INFO)
    monkeypatch.setattr(merge3, "DATA_DIR", tmp_path)
    _write(tmp_path / "project-b_edr.csv", [_agent()])
    _write(tmp_path / "project-b-ad.csv", [_ad_row()])
    _write(tmp_path / "vmware-inventory.csv", [_ad_row(hostname="esx-01")])
    _write(tmp_path / "edr_coverage_report.csv", [_ad_row()])  # own output — not a signal

    merge3.discover_companies()

    assert "vmware-inventory.csv" in caplog.text
    assert "edr_coverage_report.csv" not in caplog.text


def test_agents_without_inventory_counted_per_tenant(tmp_path, monkeypatch, caplog):
    """
    Companies of one tenant share one _edr.csv: a neighbour's agent must not
    be treated as ownerless, and the overall total must not be summed per company.
    """
    caplog.set_level(logging.INFO)
    monkeypatch.setattr(merge3, "DATA_DIR", tmp_path)
    agents = [_agent(name="HOST-A"), _agent(name="HOST-B"), _agent(name="NOBODYS-HOST")]
    for company, host in (("alpha", "host-a"), ("beta", "host-b")):
        _write(tmp_path / f"{company}_edr.csv", agents)
        _write(tmp_path / f"{company}-ad.csv", [_ad_row(hostname=host)])

    _, overall = merge3.build_report()

    per_company = {c: m["AGENTS_WITHOUT_INVENTORY"] for c, m in overall["COMPANIES"].items()}
    assert per_company == {"alpha": 1, "beta": 1}, "a foreign tenant agent is not ownerless"
    assert overall["AGENTS_WITHOUT_INVENTORY"] == 1, "the tenant is counted once"
    assert "NOBODYS-HOST" in caplog.text


def test_load_edr_keeps_every_column_matching_needs(tmp_path, monkeypatch):
    """
    The loader used to pick columns by an allow-list, and a forgotten column
    silently disabled its logic — that is why lastuser hints never worked, and
    before that the IP pass failed for the same reason.
    """
    monkeypatch.setattr(merge3, "DATA_DIR", tmp_path)
    _write(tmp_path / "x_edr.csv", [_agent(inv_hostname="host-01", mac="fa:16:3e:00:00:01")])

    got = set(merge3.load_edr("x").columns)

    needed = {
        merge3.EDR_NAME_COL, merge3.EDR_ONLINE_COL, merge3.EDR_IP_COL,
        merge3.EDR_LASTSEEN_COL, merge3.EDR_OSNAME_COL, merge3.EDR_DISPLAYNAME_COL,
        merge3.EDR_INV_HOSTNAME_COL, merge3.EDR_LASTUSER_COL,
    }
    assert needed <= got, f"loader dropped: {needed - got}"


def test_alias_candidates_survive_the_loader(tmp_path, monkeypatch, caplog):
    # the same path as production: CSV -> load_edr -> passes -> hint
    caplog.set_level(logging.INFO)
    monkeypatch.setattr(merge3, "DATA_DIR", tmp_path)
    _write(tmp_path / "project-e_edr.csv", [_agent(name="MAC", displayname="Mac.loc",
                                                 osname="macOS 26.5", lastuser="a.user")])
    _write(tmp_path / "project-e-ad.csv", [_ad_row(hostname="m-user-a")])

    merge3.build_report()

    assert "m-user-a -> MAC" in caplog.text
def test_source_type_comes_from_the_column_when_present(tmp_path, monkeypatch):
    # AD now returns both servers and workstations in one file
    monkeypatch.setattr(merge3, "DATA_DIR", tmp_path)
    _write(tmp_path / "x-ad.csv", [
        {"hostname": "w-proj-a-1", "sourceip": "", "enabled": "True", "dn": "OU=L", "source_type": "workstation"},
        {"hostname": "app02", "sourceip": "", "enabled": "True", "dn": "OU=S", "source_type": "server"},
    ])
    got = merge3.load_vm("x", [tmp_path / "x-ad.csv"]).set_index("hostname")
    assert got.at["app02", "source_type"] == "server"
    assert got.at["w-proj-a-1", "source_type"] == "workstation"
    assert bool(got.at["app02", "in_ad"]) is True, "a server from AD is still domain-joined"


def test_source_type_falls_back_to_the_file_suffix(tmp_path, monkeypatch):
    monkeypatch.setattr(merge3, "DATA_DIR", tmp_path)
    _write(tmp_path / "x-ad.csv", [{"hostname": "w-1", "sourceip": "", "enabled": "True", "dn": "OU=L"}])
    _write(tmp_path / "x-vkcloud.csv", [{"hostname": "vm-1", "sourceip": "10.0.0.1", "managed": ""}])
    got = merge3.load_vm("x", [tmp_path / "x-ad.csv", tmp_path / "x-vkcloud.csv"]).set_index("hostname")
    assert got.at["w-1", "source_type"] == "workstation"
    assert got.at["vm-1", "source_type"] == "server"


def test_broken_source_type_value_falls_back_instead_of_leaking(tmp_path, monkeypatch):
    monkeypatch.setattr(merge3, "DATA_DIR", tmp_path)
    _write(tmp_path / "x-ad.csv", [{"hostname": "w-1", "sourceip": "", "enabled": "True",
                                    "dn": "OU=L", "source_type": "garbage"}])
    got = merge3.load_vm("x", [tmp_path / "x-ad.csv"])
    assert got.iloc[0]["source_type"] == "workstation"


def test_domain_server_without_ip_still_counts():
    # AD does not store addresses: requiring sourceip from a domain server would
    # silently drop it from the denominator
    df = pd.DataFrame([_vm(hostname="app02", sourceip="", in_ad=True, enabled="True",
                           excluded=False, source_type="server")])
    assert bool(merge3._in_pool(df).iloc[0]) is True


def test_disabled_domain_server_is_out_of_pool():
    df = pd.DataFrame([_vm(hostname="app02", sourceip="", in_ad=True, enabled="False",
                           excluded=False, source_type="server")])
    assert bool(merge3._in_pool(df).iloc[0]) is False


def test_cloud_server_without_ip_is_still_skipped():
    # for cloud VMs an empty address means a half-created/broken record
    df = pd.DataFrame([_vm(hostname="vm-1", sourceip="", in_ad=False, source_type="server")])
    assert bool(merge3._in_pool(df).iloc[0]) is False


def test_ad_row_moves_to_the_company_that_owns_the_cloud_vm(tmp_path, monkeypatch, caplog):
    """
    dependencytrack sits in the shared OU=Servers and went to project-a as
    default_company, though it is a project-c VM. The cloud account is a fact,
    OU assignment is a heuristic, so the AD row moves to the cloud-VM owner.
    """
    caplog.set_level(logging.INFO)
    monkeypatch.setattr(merge3, "DATA_DIR", tmp_path)
    for company in ("project-a", "project-c"):
        _write(tmp_path / f"{company}_edr.csv", [_agent(name="DEPENDENCYTRACK")])
    _write(tmp_path / "project-a-ad.csv",
           [_ad_row(hostname="dependencytrack", source_type="server", dn="OU=Servers,DC=corp")])
    _write(tmp_path / "project-c-sbc-adv.csv",
           [{"hostname": "dependencytrack", "sourceip": "10.0.8.203", "managed": ""}])

    final, _ = merge3.build_report()

    rows = final[final.hostname == "dependencytrack"]
    assert len(rows) == 1, "the host must not be counted under two companies"
    assert rows.iloc[0]["company"] == "project-c"
    assert bool(rows.iloc[0]["in_ad"]) is True, "the domain flag is not lost on the move"


def test_same_name_in_two_clouds_is_not_matched_by_name(tmp_path, monkeypatch, caplog):
    """
    lb-waf-prod-01 exists at project-b (10.0.13.96) and project-c (10.0.9.165) —
    two different machines. There is one agent with that name, and by name it
    went to both: the project-b server was counted as covered by a foreign agent.
    """
    caplog.set_level(logging.WARNING)
    monkeypatch.setattr(merge3, "DATA_DIR", tmp_path)
    for company in ("project-b", "project-c"):
        _write(tmp_path / f"{company}_edr.csv",
               [_agent(name="LB-WAF-PROD-01", sourceip="10.0.9.165")])
    _write(tmp_path / "project-b-sbc-adv.csv",
           [{"hostname": "lb-waf-prod-01", "sourceip": "10.0.13.96", "managed": ""}])
    _write(tmp_path / "project-c-sbc-adv.csv",
           [{"hostname": "lb-waf-prod-01", "sourceip": "10.0.9.165", "managed": ""}])

    final, _ = merge3.build_report()

    assert "Same name on machines of different companies" in caplog.text
    by_company = final.set_index("company")
    assert not bool(by_company.at["project-b", "has_edr"]), "a foreign agent must not cover the host"
    # IP tells the machines apart where the name is no longer a key
    assert by_company.at["project-c", "matched_by"] == "ip"


def test_name_matched_but_addresses_contradict_warns(caplog):
    # addresses match in 129 of 129 pairs, so a mismatch is a signal, not noise
    caplog.set_level(logging.WARNING)
    vm = pd.DataFrame([_vm(hostname="app-01", sourceip="10.0.1.5")])
    edr = pd.DataFrame([_agent(name="APP-01", sourceip="10.9.9.9")])
    out = merge3._merge_with_edr(vm, edr).iloc[0]
    assert out["has_edr"], "the name match stays: an address is not required"
    assert "addresses diverged" in caplog.text


def test_no_warning_when_one_side_has_no_address(caplog):
    # domain hosts have no address at all — that is normal, not a contradiction
    caplog.set_level(logging.WARNING)
    vm = pd.DataFrame([_vm(hostname="app-01", sourceip="", in_ad=True, enabled="True")])
    edr = pd.DataFrame([_agent(name="APP-01", sourceip="10.9.9.9")])
    merge3._merge_with_edr(vm, edr)
    assert "addresses diverged" not in caplog.text
