#!/usr/bin/env python3
"""IT report on EDR gaps: host lists to fix, grouped by company.

Source is edr_coverage_report.csv (written by merge3/the exporter into EDR_DATA_DIR).
Two lists:

  1. "No EDR agent" — host is in the pool, no agent. Deliver an agent. No
     time window: the state is stable.
  2. "Agent present but silent" — agent is installed, but last contact is older
     than a window that DEPENDS ON HOST TYPE:
       workstation > 14 days  (person on leave/sick — this is NOT an incident),
       server      > 24 hours (a server must stay in contact).
     Instant offline is not counted: workstations powered off at night and
     server reboots must not spawn tickets.

Output: human-readable text (stdout) + CSV with all hosts. Delivery is a
swappable backend (--to stdout|file|email); email/Jira can be wired when a
concrete intake is known. Run: python edr_report.py [--to ...].
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

# Silence windows before a ticket, by host type.
WS_SILENT_DAYS = float(os.environ.get("EDR_SILENT_WS_DAYS", "14"))
SRV_SILENT_HOURS = float(os.environ.get("EDR_SILENT_SRV_HOURS", "24"))

DASHBOARD_URL = os.environ.get("EDR_DASHBOARD_URL", "http://10.10.1.10:3000/d/edr-coverage")


def _silent_window_seconds(host_type: str) -> float:
    return WS_SILENT_DAYS * 86400 if host_type == "workstation" else SRV_SILENT_HOURS * 3600


def build_lists(now: float | None = None) -> tuple[pd.DataFrame, pd.DataFrame]:
    """Return (no_agent, silent) — both already filtered to the pool."""
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
    """Host list by company for the email body."""
    if df.empty:
        return "  (none)\n"
    out = []
    for company, g in df.sort_values(["company", "hostname"]).groupby("company"):
        out.append("  %s (%d):" % (company, len(g)))
        for r in g.itertuples():
            if with_age:
                out.append("    - %-40s %s (%.0f days without contact)"
                           % (r.hostname, r.source_type, r.days_silent))
            else:
                out.append("    - %-40s %s" % (r.hostname, r.source_type))
    return "\n".join(out) + "\n"


def render_text(no_agent: pd.DataFrame, silent: pd.DataFrame) -> tuple[str, str]:
    """Return (subject, body)."""
    subject = "EDR: %d hosts without an agent, %d with a silent agent" % (len(no_agent), len(silent))
    body = [
        "EDR coverage report — hosts that need IT action.",
        "Dashboard: %s" % DASHBOARD_URL,
        "",
        "=== Hosts without an EDR agent — agent must be delivered (%d) ===" % len(no_agent),
        _fmt_group(no_agent, with_age=False),
        "=== Agent present but silent — investigate, do not reinstall (%d) ===" % len(silent),
        "    (threshold: workstation > %.0f days, server > %.0f h without contact)"
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
        print("report -> %s ; %s" % (out, csv_path))
    elif target == "email":
        send_email(subject, body, csv_path)
    else:
        raise SystemExit("unknown --to: %s" % target)


def send_email(subject: str, body: str, csv_path: Path) -> None:
    """Send to a Jira intake address. Configured via the environment:
       EDR_SMTP_HOST[:PORT], EDR_SMTP_FROM, EDR_REPORT_TO (recipient),
       optional EDR_SMTP_USER/EDR_SMTP_PASSWORD, EDR_SMTP_STARTTLS=1.
    The exact Jira path is TBD — the backend is ready, remaining work is addresses."""
    import smtplib
    from email.message import EmailMessage

    host = os.environ.get("EDR_SMTP_HOST")
    sender = os.environ.get("EDR_SMTP_FROM")
    rcpt = os.environ.get("EDR_REPORT_TO")
    if not (host and sender and rcpt):
        raise SystemExit("for --to email set EDR_SMTP_HOST/EDR_SMTP_FROM/EDR_REPORT_TO")
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
    print("mail sent: %s -> %s" % (sender, rcpt))


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--to", default="stdout", choices=["stdout", "file", "email"],
                    help="where to deliver the report (default stdout)")
    args = ap.parse_args()

    if not REPORT_CSV.exists():
        raise SystemExit("missing %s — collection must run first" % REPORT_CSV)

    no_agent, silent = build_lists()
    subject, body = render_text(no_agent, silent)
    csv_path = DATA_DIR / "edr_report.csv"
    write_csv(no_agent, silent, csv_path)
    deliver(args.to, subject, body, csv_path)


if __name__ == "__main__":
    main()
