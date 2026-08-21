"""YAML-конфиг cert-orchestrator."""

from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, List, Optional

import yaml

from schedule import parse_weekday_value, weekday_index


@dataclass
class MetaConfig:
    environment: str = "preprod"
    timezone: str = "UTC"


@dataclass
class ScheduleConfig:
    days_interval: int = 7
    renew_on_container_start: bool = True
    weekday: str = "tuesday"
    time_hhmm: str = "03:30"
    poll_interval_seconds: int = 3600

    def weekday_as_index(self) -> int:
        return weekday_index(self.weekday)


@dataclass
class RegruDnsConfig:
    dns_username: str = ""
    dns_password: str = ""


@dataclass
class LetsEncryptConfig:
    email: str = ""
    domain: str = ""
    regru: RegruDnsConfig = field(default_factory=RegruDnsConfig)
    regru_ini_path: str = ""
    live_dir: str = ""
    certbot_extra_args: List[str] = field(default_factory=list)
    dns_propagation_seconds: int = 360


@dataclass
class TimeoutsConfig:
    certbot_seconds: int = 1800
    kubectl_seconds: int = 300
    ssh_connect_seconds: int = 60
    ssh_command_seconds: int = 300
    openssl_checkend_seconds: int = 86400


@dataclass
class KubernetesConfig:
    enabled: bool = False
    api_server: str = ""
    ca_cert_path: str = "/run/cert-orchestrator/k8s-ca.crt"
    insecure_skip_tls_verify: bool = False
    namespace_secrets: List["NamespaceSecretConfig"] = field(default_factory=list)


@dataclass
class NamespaceSecretConfig:
    namespace: str = ""
    secret_name: str = "wildcard-tls"


@dataclass
class NginxHostConfig:
    host: str = ""
    user: str = "root"
    identity_file: str = ""
    ssl_dir: str = "/etc/nginx/ssl"
    cert_basename: str = ""
    nginx_container: str = ""


@dataclass
class NginxRemotesConfig:
    enabled: bool = False
    hosts: List[NginxHostConfig] = field(default_factory=list)


@dataclass
class TargetsConfig:
    nginx_remotes: NginxRemotesConfig = field(default_factory=NginxRemotesConfig)


@dataclass
class TelegramNotifyOnConfig:
    container_start: bool = True
    errors: bool = True
    renewal_started: bool = True
    renewal_finished: bool = True
    per_host_result: bool = True
    next_rotation_reminder: bool = True


@dataclass
class TelegramConfig:
    bot_token: str = ""
    chat_ids: List[str] = field(default_factory=list)
    connect_timeout_seconds: int = 30
    total_timeout_seconds: int = 90
    retry_attempts: int = 5
    retry_delay_seconds: int = 6
    notify_on: TelegramNotifyOnConfig = field(default_factory=TelegramNotifyOnConfig)


@dataclass
class LoggingConfig:
    level: str = "INFO"
    format: str = "text"


@dataclass
class HttpsCheckHostConfig:
    host: str = ""
    port: int = 443
    enabled: bool = True
    sni: str = ""


@dataclass
class HttpsVerificationConfig:
    enabled: bool = False
    ssl_timeout_seconds: int = 15
    hosts: List[HttpsCheckHostConfig] = field(default_factory=list)


@dataclass
class OrchestratorConfig:
    meta: MetaConfig = field(default_factory=MetaConfig)
    schedule: ScheduleConfig = field(default_factory=ScheduleConfig)
    letsencrypt: LetsEncryptConfig = field(default_factory=LetsEncryptConfig)
    timeouts: TimeoutsConfig = field(default_factory=TimeoutsConfig)
    kubernetes: KubernetesConfig = field(default_factory=KubernetesConfig)
    targets: TargetsConfig = field(default_factory=TargetsConfig)
    telegram: TelegramConfig = field(default_factory=TelegramConfig)
    logging: LoggingConfig = field(default_factory=LoggingConfig)
    https_verification: HttpsVerificationConfig = field(default_factory=HttpsVerificationConfig)


def _merge_telegram_env(cfg: OrchestratorConfig) -> None:
    token = os.environ.get("TELEGRAM_BOT_TOKEN", "").strip()
    if token:
        cfg.telegram.bot_token = token
    chats = os.environ.get("TELEGRAM_CHAT_IDS", "").strip()
    if chats:
        cfg.telegram.chat_ids = [c.strip() for c in chats.split(",") if c.strip()]


def _merge_regru_env(cfg: OrchestratorConfig) -> None:
    u = os.environ.get("REG_RU_DNS_USERNAME", "").strip()
    if u:
        cfg.letsencrypt.regru.dns_username = u
    p = os.environ.get("REG_RU_DNS_PASSWORD", "").strip()
    if p:
        cfg.letsencrypt.regru.dns_password = p


def load_config(path: str | Path) -> OrchestratorConfig:
    p = Path(path)
    if not p.is_file():
        raise FileNotFoundError(f"Конфиг не найден: {p}")

    raw: dict[str, Any]
    with p.open("r", encoding="utf-8") as f:
        raw = yaml.safe_load(f) or {}

    m = raw.get("meta") or {}
    meta = MetaConfig(
        environment=str(m.get("environment", "preprod")),
        timezone=str(m.get("timezone", "UTC")),
    )

    sch = raw.get("schedule", {})
    wd_raw = sch.get("weekday", "tuesday")
    days_raw = sch.get("days_interval")
    if days_raw is None:
        days_raw = sch.get(
            "min_days_between_attempts",
            sch.get("min_days_since_success", 7),
        )
    schedule = ScheduleConfig(
        days_interval=int(days_raw),
        renew_on_container_start=bool(sch.get("renew_on_container_start", True)),
        weekday=parse_weekday_value(wd_raw),
        time_hhmm=str(sch.get("time_hhmm", "03:30")),
        poll_interval_seconds=int(sch.get("poll_interval_seconds", 3600)),
    )

    le = raw.get("letsencrypt", {})
    regru_raw = le.get("regru") or {}
    regru = RegruDnsConfig(
        dns_username=str(regru_raw.get("dns_username", "")),
        dns_password=str(regru_raw.get("dns_password", "")),
    )
    letsencrypt = LetsEncryptConfig(
        email=str(le.get("email", "")),
        domain=str(le.get("domain", "")),
        regru=regru,
        regru_ini_path=str(le.get("regru_ini_path", "")),
        live_dir=str(le.get("live_dir", "")),
        certbot_extra_args=list(le.get("certbot_extra_args") or []),
        dns_propagation_seconds=int(le.get("dns_propagation_seconds", 360)),
    )

    to = raw.get("timeouts", {})
    timeouts = TimeoutsConfig(**{k: int(to.get(k, getattr(TimeoutsConfig(), k))) for k in TimeoutsConfig.__dataclass_fields__})

    k8 = raw.get("kubernetes", {})
    ns_secrets: List[NamespaceSecretConfig] = []
    for item in k8.get("namespace_secrets") or []:
        ns = str(item.get("namespace", "")).strip()
        sn = str(item.get("secret_name", "wildcard-tls")).strip()
        if ns and sn:
            ns_secrets.append(NamespaceSecretConfig(namespace=ns, secret_name=sn))
    kubernetes = KubernetesConfig(
        enabled=bool(k8.get("enabled", False)),
        api_server=str(k8.get("api_server", "")),
        ca_cert_path=str(k8.get("ca_cert_path", "/run/cert-orchestrator/k8s-ca.crt")),
        insecure_skip_tls_verify=bool(k8.get("insecure_skip_tls_verify", False)),
        namespace_secrets=ns_secrets,
    )

    tg = raw.get("telegram", {})
    notify_raw = tg.get("notify_on") or {}
    notify_on = TelegramNotifyOnConfig(
        container_start=bool(notify_raw.get("container_start", True)),
        errors=bool(notify_raw.get("errors", True)),
        renewal_started=bool(notify_raw.get("renewal_started", True)),
        renewal_finished=bool(notify_raw.get("renewal_finished", True)),
        per_host_result=bool(notify_raw.get("per_host_result", True)),
        next_rotation_reminder=bool(notify_raw.get("next_rotation_reminder", True)),
    )
    telegram = TelegramConfig(
        bot_token=str(tg.get("bot_token", "")),
        chat_ids=[str(x) for x in (tg.get("chat_ids") or [])],
        connect_timeout_seconds=int(tg.get("connect_timeout_seconds", 30)),
        total_timeout_seconds=int(tg.get("total_timeout_seconds", 90)),
        retry_attempts=int(tg.get("retry_attempts", 5)),
        retry_delay_seconds=int(tg.get("retry_delay_seconds", 6)),
        notify_on=notify_on,
    )

    tr = raw.get("targets", {})
    nr = tr.get("nginx_remotes", {})
    nginx_hosts = []
    for h in nr.get("hosts") or []:
        nginx_hosts.append(
            NginxHostConfig(
                host=str(h.get("host", "")),
                user=str(h.get("user", "root")),
                identity_file=str(h.get("identity_file", "")),
                ssl_dir=str(h.get("ssl_dir", "/etc/nginx/ssl")),
                cert_basename=str(h.get("cert_basename", "")),
                nginx_container=str(h.get("nginx_container", "")),
            )
        )
    nginx_remotes = NginxRemotesConfig(enabled=bool(nr.get("enabled", False)), hosts=nginx_hosts)

    targets = TargetsConfig(nginx_remotes=nginx_remotes)

    log = raw.get("logging", {})
    logging_cfg = LoggingConfig(level=str(log.get("level", "INFO")), format=str(log.get("format", "text")))

    hv_raw = raw.get("https_verification") or {}
    hv_hosts = []
    for x in hv_raw.get("hosts") or []:
        hv_hosts.append(
            HttpsCheckHostConfig(
                host=str(x.get("host", "")),
                port=int(x.get("port", 443)),
                enabled=bool(x.get("enabled", True)),
                sni=str(x.get("sni", "")),
            )
        )
    https_verification = HttpsVerificationConfig(
        enabled=bool(hv_raw.get("enabled", False)),
        ssl_timeout_seconds=int(hv_raw.get("ssl_timeout_seconds", 15)),
        hosts=hv_hosts,
    )

    cfg = OrchestratorConfig(
        meta=meta,
        schedule=schedule,
        letsencrypt=letsencrypt,
        timeouts=timeouts,
        kubernetes=kubernetes,
        targets=targets,
        telegram=telegram,
        logging=logging_cfg,
        https_verification=https_verification,
    )
    _merge_telegram_env(cfg)
    _merge_regru_env(cfg)
    return cfg
