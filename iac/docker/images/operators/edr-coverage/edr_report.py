#!/usr/bin/env python3
"""Отчёт для IT по пробелам EDR: списки хостов на починку, сгруппированные по компаниям.

Источник — edr_coverage_report.csv (его пишет merge3/экспортер в EDR_DATA_DIR).
Два списка:

  1. «Нет агента EDR» — хост в пуле, агента нет. Донести агент. Без окна по
     времени: состояние стабильное.
  2. «Агент есть, но молчит» — агент установлен, но последняя связь старше окна,
     ЗАВИСЯЩЕГО ОТ ТИПА ХОСТА:
       workstation > 14 дней  (человек в отпуске/болеет — это НЕ инцидент),
       server      > 24 часов (сервер обязан быть на связи).
     Мгновенный офлайн не считаем: ночью выключенные АРМ и перезагрузки сервера
     не должны плодить тикеты.

Выход: человекочитаемый текст (stdout) + CSV со всеми хостами. Доставка —
сменный бэкенд (--to stdout|file|email); email/Jira подключим, когда известен
конкретный intake. Запуск: python edr_report.py [--to ...].
"""

import argparse
import csv
import os
import sys
import time
from pathlib import Path

import pandas as pd

DATA_DIR = Path(os.environ.get("EDR_DATA_DIR", "."))
REPORT_CSV = DATA_DIR / "edr_coverage_report.csv"

# Окна «молчания» до попадания в тикет, по типу хоста.
WS_SILENT_DAYS = float(os.environ.get("EDR_SILENT_WS_DAYS", "14"))
SRV_SILENT_HOURS = float(os.environ.get("EDR_SILENT_SRV_HOURS", "24"))

DASHBOARD_URL = os.environ.get("EDR_DASHBOARD_URL", "http://10.10.1.10:3000/d/edr-coverage")


def _silent_window_seconds(host_type: str) -> float:
    return WS_SILENT_DAYS * 86400 if host_type == "workstation" else SRV_SILENT_HOURS * 3600


def build_lists(now: float | None = None) -> tuple[pd.DataFrame, pd.DataFrame]:
    """Вернуть (нет_агента, молчит) — оба уже отфильтрованы и по пулу."""
    now = now if now is not None else time.time()
    df = pd.read_csv(REPORT_CSV)
    pool = df[df["in_pool"]].copy()

    no_agent = pool[~pool["has_edr"].astype(bool)].copy()

    with_agent = pool[pool["has_edr"].astype(bool)].copy()
    with_agent = with_agent[with_agent["edr_last_seen"].notna()]
    age = now - with_agent["edr_last_seen"]
    window = with_agent["source_type"].map(_silent_window_seconds)
    silent = with_agent[age > window].copy()
    silent["days_silent"] = ((now - silent["edr_last_seen"]) / 86400).round(1)
    return no_agent, silent


def _fmt_group(df: pd.DataFrame, with_age: bool) -> str:
    """Список хостов по компаниям для текста письма."""
    if df.empty:
        return "  (нет)\n"
    out = []
    for company, g in df.sort_values(["company", "hostname"]).groupby("company"):
        out.append("  %s (%d):" % (company, len(g)))
        for r in g.itertuples():
            if with_age:
                out.append("    - %-40s %s (%.0f дн. без связи)"
                           % (r.hostname, r.source_type, r.days_silent))
            else:
                out.append("    - %-40s %s" % (r.hostname, r.source_type))
    return "\n".join(out) + "\n"


def render_text(no_agent: pd.DataFrame, silent: pd.DataFrame) -> tuple[str, str]:
    """Вернуть (subject, body)."""
    subject = "EDR: %d хостов без агента, %d с молчащим агентом" % (len(no_agent), len(silent))
    body = [
        "Отчёт по покрытию EDR — хосты, требующие действий IT.",
        "Дашборд: %s" % DASHBOARD_URL,
        "",
        "=== Хосты без агента EDR — на них надо донести (%d) ===" % len(no_agent),
        _fmt_group(no_agent, with_age=False),
        "=== Агент есть, но молчит — разбираться, а не переустанавливать (%d) ===" % len(silent),
        "    (порог: АРМ > %.0f дн., сервер > %.0f ч. без связи)"
        % (WS_SILENT_DAYS, SRV_SILENT_HOURS),
        _fmt_group(silent, with_age=True),
    ]
    return subject, "\n".join(body)


def write_csv(no_agent: pd.DataFrame, silent: pd.DataFrame, path: Path) -> None:
    with path.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["category", "company", "hostname", "host_type", "days_silent"])
        for r in no_agent.sort_values(["company", "hostname"]).itertuples():
            w.writerow(["no_agent", r.company, r.hostname, r.source_type, ""])
        for r in silent.sort_values(["company", "hostname"]).itertuples():
            w.writerow(["silent_agent", r.company, r.hostname, r.source_type, r.days_silent])


def deliver(target: str, subject: str, body: str, csv_path: Path) -> None:
    if target == "stdout":
        print(subject)
        print(body)
        print("CSV: %s" % csv_path)
    elif target == "file":
        out = DATA_DIR / "edr_report.txt"
        out.write_text(subject + "\n\n" + body, encoding="utf-8")
        print("отчёт -> %s ; %s" % (out, csv_path))
    elif target == "email":
        send_email(subject, body, csv_path)
    else:
        raise SystemExit("неизвестный --to: %s" % target)


def send_email(subject: str, body: str, csv_path: Path) -> None:
    """Отправка на intake-адрес Jira. Настраивается через окружение:
       EDR_SMTP_HOST[:PORT], EDR_SMTP_FROM, EDR_REPORT_TO (получатель),
       опц. EDR_SMTP_USER/EDR_SMTP_PASSWORD, EDR_SMTP_STARTTLS=1.
    Конкретный способ Jira уточняется — бэкенд готов, останется задать адреса."""
    import smtplib
    from email.message import EmailMessage

    host = os.environ.get("EDR_SMTP_HOST")
    sender = os.environ.get("EDR_SMTP_FROM")
    rcpt = os.environ.get("EDR_REPORT_TO")
    if not (host and sender and rcpt):
        raise SystemExit("для --to email задайте EDR_SMTP_HOST/EDR_SMTP_FROM/EDR_REPORT_TO")
    host, _, port = host.partition(":")

    msg = EmailMessage()
    msg["Subject"], msg["From"], msg["To"] = subject, sender, rcpt
    msg.set_content(body)
    msg.add_attachment(csv_path.read_bytes(), maintype="text", subtype="csv",
                       filename=csv_path.name)

    with smtplib.SMTP(host, int(port or 25), timeout=30) as s:
        if os.environ.get("EDR_SMTP_STARTTLS") == "1":
            s.starttls()
        user, pwd = os.environ.get("EDR_SMTP_USER"), os.environ.get("EDR_SMTP_PASSWORD")
        if user and pwd:
            s.login(user, pwd)
        s.send_message(msg)
    print("письмо отправлено: %s -> %s" % (sender, rcpt))


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--to", default="stdout", choices=["stdout", "file", "email"],
                    help="куда доставить отчёт (по умолчанию stdout)")
    args = ap.parse_args()

    if not REPORT_CSV.exists():
        raise SystemExit("нет %s — сначала должен отработать сбор" % REPORT_CSV)

    no_agent, silent = build_lists()
    subject, body = render_text(no_agent, silent)
    csv_path = DATA_DIR / "edr_report.csv"
    write_csv(no_agent, silent, csv_path)
    deliver(args.to, subject, body, csv_path)


if __name__ == "__main__":
    main()
