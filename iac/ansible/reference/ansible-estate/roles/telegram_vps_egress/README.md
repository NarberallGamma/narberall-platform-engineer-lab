# telegram_vps_egress

Local Envoy на GitLab: TCP proxy к VPS cluster (PRIORITY failover) для Telegram API.

Конфигурация роли: **`group_vars/telegram_vps_egress.yml`** (только плейбук `telegram_vps_egress.yml`).  
Клиент docker_app: **`docker_app.telegram_egress`** в `group_vars/<service>.yml`, без общих vars с egress.

См. **`docs/TELEGRAM_VPS_EGRESS_GITLAB.md`**.
