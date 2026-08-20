# Telegram VPS egress на GitLab (local Envoy)

Local Envoy в Docker-сети `telegram-vps-egress`: TCP proxy с failover VPS-01 -> VPS-02.  
Контейнеры docker_app подключаются к сети и резолвят `api.telegram.org` в IP proxy (без bind :443 на хосте, nginx GitLab не затрагивается).

## Изоляция плейбуков

| Слой | Плейбук | group_vars | Переменные |
|------|---------|------------|------------|
| **Egress proxy** | `telegram_vps_egress.yml` | `telegram_vps_egress.yml` | `telegram_vps_egress_*` (сеть, Envoy, VPS backends) |
| **Docker apps (клиент)** | `docker_app_*.yml` | `group_vars/<service>.yml` | `docker_app.telegram_egress.*` |

Плейбуки **не** подключают чужие `vars_files`. Egress деплоится отдельно; docker_app только подключает external network и `extra_hosts` по своим vars.

Согласование вручную: `network_name` и IP в `extra_hosts` должны совпадать с тем, что создаёт egress (`telegram-vps-egress`, `172.30.100.2` по умолчанию).

## Компоненты egress

| Компонент | Путь / имя |
|-----------|------------|
| Роль | `roles/telegram_vps_egress/` |
| Плейбук | `playbooks/telegram_vps_egress.yml` |
| Inventory group | `[telegram_vps_egress]` |
| group_vars | `group_vars/telegram_vps_egress.yml` |
| Proxy на хосте | `/docker/apps/telegram-vps-egress/` |
| Docker network | `telegram-vps-egress` (`telegram_vps_egress_subnet`) |
| Proxy IP | `telegram_vps_egress_proxy_ip` |

## Порядок деплоя

```bash
cd /ansible && source .env.vault

# 1. Proxy (один раз или после смены VPS backends)
./scripts/run/run_telegram_vps_egress.sh --preprod --limit estate-preprod-gitlab

# 2. Пересобрать compose приложений (подключат network + extra_hosts)
./scripts/run/run_docker_app.sh deploy cert-monitoring --preprod --limit estate-preprod-gitlab
./scripts/run/run_docker_app.sh deploy cert-orchestrator --preprod --limit estate-preprod-gitlab
```

Prod: `--prod --limit estate-prod-gitlab` (cert-monitoring, cloud-hibernate-operator).

## Клиентские vars (docker_app)

В `group_vars/<service>.yml` внутри `docker_app` (без ссылок на `telegram_vps_egress_*`):

```yaml
docker_app:
  telegram_egress:
    enabled: true
    network_name: telegram-vps-egress
    extra_hosts:
      - name: api.telegram.org
        ip: 172.30.100.2
```

При смене subnet/proxy IP в egress: обновить `extra_hosts` в каждом сервисе отдельно.

## Схема

```text
docker app (cert-monitoring / orchestrator / hibernate)
  extra_hosts: api.telegram.org -> 172.30.100.2
  network: telegram-vps-egress (external)
        |
        v
  telegram-vps-egress (Envoy, PRIORITY LB)
        |
   +----+----+
   v         v
 VPS-01    VPS-02
   v         v
 Telegram API
```

## Проверка

```bash
docker ps --filter name=telegram-vps-egress
docker network inspect telegram-vps-egress
docker exec cert-monitoring getent hosts api.telegram.org
# 172.30.100.2  api.telegram.org

docker exec cert-monitoring curl -sv --max-time 15 \
  https://api.telegram.org/bot<TOKEN>/getMe 2>&1 | tail -15
```

## Откат

1. В service group_vars: `telegram_egress.enabled: false`, при необходимости legacy `docker_app_telegram_vps_enabled: true`.
2. Redeploy docker_app.
3. Остановить proxy: `docker compose -f /docker/apps/telegram-vps-egress/docker-compose.yml down`

См. также: `roles/telegram_vps_egress/README.md`, `DOCKER_APPS.md`
