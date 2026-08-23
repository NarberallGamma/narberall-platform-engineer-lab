# telegram_vps_egress

Local Envoy on GitLab: TCP proxy to the VPS cluster (PRIORITY failover) for Telegram API.

Role configuration: **`group_vars/telegram_vps_egress.yml`** (playbook `telegram_vps_egress.yml` only).  
docker_app client: **`docker_app.telegram_egress`** in `group_vars/<service>.yml`, with no shared vars with egress.

See **`docs/TELEGRAM_VPS_EGRESS_GITLAB.md`**.
