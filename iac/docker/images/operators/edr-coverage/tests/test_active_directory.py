"""
Тесты раздачи хостов AD по компаниям.

LDAP тут не нужен: проверяются чистые функции, которые решают, чей хост и какого
он типа. Именно в этом месте раньше терялись машины — хост, не подошедший ни под
чьи паттерны, молча не попадал никуда.
"""
import importlib.util
import logging
import pathlib

import pytest

spec = importlib.util.spec_from_file_location(
    "active_directory", pathlib.Path(__file__).resolve().parent.parent / "active-directory.py")
ad = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ad)

LAPTOPS = "OU=Laptops,OU=Assets,DC=corp,DC=example,DC=ru"
SERVERS = "OU=Ubuntu,OU=Servers,OU=Assets,DC=corp,DC=example,DC=ru"


def _host(**over) -> dict:
    row = {"hostname": "w-proj-a-00001", "fqdn": "w-proj-a-00001.corp.example.com", "sourceip": "",
           "os": "Windows 11 Pro", "os_version": "10.0", "dn": None,
           "enabled": True, "is_dc": False}
    row.update(over)
    # DN выводим из имени: одинаковый DN у разных хостов — артефакт фикстуры,
    # раздача теперь дедуплицирует именно по DN
    if row["dn"] is None:
        row["dn"] = f"CN={row['hostname']},{LAPTOPS}"
    return row


def test_ou_entries_accepts_plain_dn_and_mapping():
    company = {"workstation_ous": [LAPTOPS], "server_ous": [{"dn": SERVERS, "source_type": "auto"}]}
    assert ad.ou_entries(company) == [(LAPTOPS, "workstation"), (SERVERS, "auto")]


@pytest.mark.parametrize("os_name, expected", [
    ("Windows Server 2022 Standard", "server"),
    ("Linux", "server"),
    ("pc-linux-gnu", "server"),      # часть Linux-машин рапортует так, префикс 'Linux*' их не ловит
    ("Windows 11 Pro", "workstation"),
    ("macOS", "workstation"),
])
def test_auto_type_follows_os(os_name, expected):
    assert ad.host_type(_host(os=os_name), "auto") == expected


def test_domain_controller_is_always_a_server():
    # единственный тип, который каталог отдаёт однозначно (primaryGroupID=516)
    assert ad.host_type(_host(is_dc=True), "workstation") == "server"


def test_declared_type_wins_over_os():
    # OU — административное решение; расхождение с ОС только логируется
    assert ad.host_type(_host(os="Windows Server 2022"), "workstation") == "workstation"


def test_host_goes_to_the_company_whose_pattern_matches():
    companies = [
        {"name": "project-a", "workstation_ous": [LAPTOPS], "hostname_patterns": ["w-proj-a-*"]},
        {"name": "project-c", "workstation_ous": [LAPTOPS], "hostname_patterns": ["w-proj-c-*"]},
    ]
    claimed, unassigned = ad.assign_hosts({LAPTOPS: [_host(hostname="w-proj-c-00001")]}, companies)
    assert not unassigned
    assert [r["hostname"] for r in claimed["project-c"]] == ["w-proj-c-00001"]
    assert claimed["project-a"] == []


def test_unclaimed_host_goes_to_the_default_company():
    companies = [
        {"name": "project-a", "workstation_ous": [LAPTOPS], "hostname_patterns": ["w-proj-a-*"],
         "default_company": True},
        {"name": "project-c", "workstation_ous": [LAPTOPS], "hostname_patterns": ["w-proj-c-*"]},
    ]
    claimed, unassigned = ad.assign_hosts({LAPTOPS: [_host(hostname="w-00000088")]}, companies)
    assert not unassigned, "хост с чужим именем не должен пропадать"
    assert [r["hostname"] for r in claimed["project-a"]] == ["w-00000088"]


def test_without_default_company_leftovers_are_reported():
    companies = [{"name": "project-a", "workstation_ous": [LAPTOPS], "hostname_patterns": ["w-proj-a-*"]}]
    claimed, unassigned = ad.assign_hosts({LAPTOPS: [_host(hostname="w-00000088")]}, companies)
    assert claimed["project-a"] == []
    assert [h["hostname"] for h in unassigned] == ["w-00000088"]


def test_server_ou_marks_rows_as_servers_and_keeps_linux():
    companies = [{"name": "project-a", "server_ous": [SERVERS], "default_company": True}]
    hosts = [_host(hostname="app02-site-a", os="pc-linux-gnu", dn=f"CN=app02-site-a,{SERVERS}")]
    claimed, unassigned = ad.assign_hosts({SERVERS: hosts}, companies)
    assert not unassigned
    assert claimed["project-a"][0]["source_type"] == "server"


def test_service_accounts_without_os_are_dropped_from_server_ous():
    # gMSA отсекаются фильтром поиска, но пустая ОС не должна доезжать и здесь
    companies = [{"name": "project-a", "server_ous": [SERVERS], "default_company": True}]
    claimed, unassigned = ad.assign_hosts({SERVERS: [_host(os="", dn=f"CN=svc,{SERVERS}")]}, companies)
    assert claimed["project-a"] == []
    assert len(unassigned) == 1


def test_workstation_os_filter_still_drops_servers_from_laptop_ous():
    companies = [{"name": "project-a", "workstation_ous": [LAPTOPS], "os_filter": "windows"}]
    hosts = [_host(hostname="srv-in-laptops", os="Windows Server 2022 Standard")]
    claimed, unassigned = ad.assign_hosts({LAPTOPS: hosts}, companies)
    assert claimed["project-a"] == []
    assert len(unassigned) == 1


def test_gmsa_is_excluded_by_object_class_in_the_search_filter():
    assert "msDS-GroupManagedServiceAccount" in ad.build_ldap_filter(True)
    assert "userAccountControl" in ad.build_ldap_filter(True)
    assert "userAccountControl" not in ad.build_ldap_filter(False)


# ---------------------------------------------------------------------------
# Порядок раздачи и валидация конфига
# ---------------------------------------------------------------------------

def test_specific_patterns_win_over_a_greedy_company_listed_first():
    """
    Авария 2026-08-17: project-a стоял первым и серверных паттернов не имел,
    поэтому выгреб 30 серверов proj-b* из общих OU раньше project-b. Порядок в конфиге
    решать не должен.
    """
    companies = [
        {"name": "project-a", "server_ous": [SERVERS], "default_company": True},
        {"name": "project-b", "server_ous": [SERVERS], "server_hostname_patterns": ["proj-b*"]},
    ]
    hosts = [_host(hostname="proj-b-prod-vault-3", os="Linux",
                   dn=f"CN=proj-b-prod-vault-3,{SERVERS}"),
             _host(hostname="app02-site-a", os="Linux", dn=f"CN=app02-site-a,{SERVERS}")]
    claimed, unassigned = ad.assign_hosts({SERVERS: hosts}, companies)
    assert [r["hostname"] for r in claimed["project-b"]] == ["proj-b-prod-vault-3"]
    assert [r["hostname"] for r in claimed["project-a"]] == ["app02-site-a"]
    assert not unassigned


def test_claims_all_is_the_explicit_form_of_an_empty_list():
    explicit = {"name": "project-a", "server_ous": [SERVERS], "server_hostname_patterns": "all"}
    implicit = {"name": "project-a", "server_ous": [SERVERS]}
    assert ad.patterns_of(explicit, "server") == ad.CLAIMS_ALL
    assert ad.patterns_of(implicit, "server") == ad.CLAIMS_ALL
    assert ad.patterns_of({"name": "project-b", "server_hostname_patterns": ["proj-b*"]}, "server") == ["proj-b*"]


def test_two_greedy_companies_on_one_ou_is_a_config_error():
    companies = [
        {"name": "project-a", "server_ous": [SERVERS]},
        {"name": "project-b", "server_ous": [SERVERS]},
    ]
    problems = ad.validate_config(companies)
    assert problems and "project-a" in problems[0] and "project-b" in problems[0]


def test_greedy_plus_specific_is_a_valid_config():
    companies = [
        {"name": "project-a", "server_ous": [SERVERS], "server_hostname_patterns": "all"},
        {"name": "project-b", "server_ous": [SERVERS], "server_hostname_patterns": ["proj-b*"]},
    ]
    assert ad.validate_config(companies) == []


def test_implicit_catch_all_is_reported(caplog):
    caplog.set_level(logging.WARNING)
    ad.validate_config([{"name": "project-a", "server_ous": [SERVERS]}])
    assert "напишите это явно" in caplog.text.lower()


def test_company_with_server_ous_and_no_servers_warns(caplog):
    # ровно тот сигнал, которого не было: 'saved 14 hosts {workstation: 14}'
    caplog.set_level(logging.WARNING)
    company = {"name": "project-b", "server_ous": [SERVERS], "workstation_ous": [LAPTOPS]}
    ad.check_empty_result(company, [{"source_type": "workstation"}])
    assert "0 хостов типа 'server'" in caplog.text


def test_company_that_got_both_types_is_quiet(caplog):
    caplog.set_level(logging.WARNING)
    company = {"name": "project-a", "server_ous": [SERVERS], "workstation_ous": [LAPTOPS]}
    ad.check_empty_result(company, [{"source_type": "workstation"}, {"source_type": "server"}])
    assert caplog.text == ""


MACOS = "OU=MacOS,OU=Laptops,OU=Assets,DC=corp,DC=example,DC=ru"


def test_nested_ou_gives_the_host_to_the_more_specific_owner():
    """
    OU=MacOS вложен в OU=Laptops, поиск идёт SUBTREE — хост приходит дважды.
    Раздав обе копии, мы отдали m-user-c и project-e (по паттерну m-*), и
    project-a (как default_company), а в покрытии он посчитался дважды.
    """
    companies = [
        {"name": "project-a", "workstation_ous": [LAPTOPS], "hostname_patterns": ["w-proj-a-*"],
         "default_company": True, "os_filter": "all"},
        {"name": "project-e", "workstation_ous": [MACOS], "hostname_patterns": ["m-*"],
         "os_filter": "all"},
    ]
    host = _host(hostname="m-user-c", os="macOS", dn=f"CN=m-user-c,{MACOS}")
    claimed, unassigned = ad.assign_hosts({LAPTOPS: [host], MACOS: [host]}, companies)

    assert [r["hostname"] for r in claimed["project-e"]] == ["m-user-c"]
    assert claimed["project-a"] == [], "хост не должен попасть в две компании сразу"
    assert not unassigned


def test_host_seen_once_is_untouched_by_the_nested_ou_rule():
    companies = [{"name": "project-a", "workstation_ous": [LAPTOPS], "hostname_patterns": "all",
                  "os_filter": "all"}]
    host = _host(hostname="w-proj-a-1", dn=f"CN=w-proj-a-1,{LAPTOPS}")
    claimed, _ = ad.assign_hosts({LAPTOPS: [host]}, companies)
    assert [r["hostname"] for r in claimed["project-a"]] == ["w-proj-a-1"]
