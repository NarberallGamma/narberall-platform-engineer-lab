# SSL certificate watcher

**Business first:** expiry is a watch, not a person who opens a browser on Friday. I ran this image as a long-running SSL checker with Telegram so a wildcard or a forgotten host pages before it dies.

Ansible deploys the same slug: [`../../../../ansible/reference/ansible-estate/`](../../../../ansible/reference/ansible-estate/). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).

```text
cert-monitoring/
  Dockerfile              # python:3.11-alpine, USER certmonitor, HEALTHCHECK
  src/
    main.py               # long-running loop
    ssl_monitor.py        # Python ssl expiry
    config.py logger.py telegram_notifier.py
    requirements.txt
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Periodic loop | `CHECK_INTERVAL_SECONDS` (default 3600). One container, not a cron of `docker run`. |
| Config file or ENV | `/etc/cert-monitoring.conf` or `MONITORED_HOSTS`. Same keys. |
| Telegram levels | Early / warning / critical / expired. `EXCLUDED_HOSTS_FROM_ALERTS` keeps flaky hosts in logs only. |
| Non-root + healthcheck | `certmonitor`. `pgrep` on `main.py`. |

```bash
docker build -t example.registry/estate/base-images/cert-monitoring:2.0 .
docker run -d --name cert-monitoring --restart unless-stopped \
  -e CONFIG_FILE=/etc/cert-monitoring.conf \
  -v /etc/cert-monitoring.conf:/etc/cert-monitoring.conf:ro \
  -v /var/log/cert-monitoring:/app/logs \
  example.registry/estate/base-images/cert-monitoring:2.0
```

One-shot (host as argv):

```bash
docker run --rm \
  -e TELEGRAM_BOT_TOKEN=CHANGE_ME \
  -e TELEGRAM_CHAT_IDS=-1000000000001 \
  example.registry/estate/base-images/cert-monitoring:2.0 \
  gitlab.example.com
```

Host list is `*.example.com`. Tokens stay in the mounted file or ENV, not in git.
