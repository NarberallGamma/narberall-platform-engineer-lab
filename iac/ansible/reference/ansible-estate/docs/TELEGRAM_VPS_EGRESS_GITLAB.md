# Telegram VPS egress on GitLab (local Envoy)

Local Envoy in Docker network `telegram-vps-egress`: TCP proxy with failover VPS-01 -> VPS-02.  
docker_app containers join the network and resolve `api.telegram.org` to the proxy IP (no bind :443 on the host; GitLab nginx is not touched).

## Playbook isolation

| Layer | Playbook | group_vars | Variables |
|------|---------|------------|------------|
| **Egress proxy** | `telegram_vps_egress.yml` | `telegram_vps_egress.yml` | `telegram_vps_egress_*` (network, Envoy, VPS backends) |
| **Docker apps (client)** | `docker_app_*.yml` | `group_vars/<service>.yml` | `docker_app.telegram_egress.*` |

Playbooks do **not** include other `vars_files`. Egress is deployed separately; docker_app only attaches the external network and `extra_hosts` from its own vars.

Manual alignment: `network_name` and the IP in `extra_hosts` must match what egress creates (`telegram-vps-egress`, `172.30.100.2` by default).

## Egress components

| Component | Path / name |
|-----------|------------|
| Role | `roles/telegram_vps_egress/` |
| Playbook | `playbooks/telegram_vps_egress.yml` |
| Inventory group | `[telegram_vps_egress]` |
| group_vars | `group_vars/telegram_vps_egress.yml` |
| Proxy on the host | `/docker/apps/telegram-vps-egress/` |
| Docker network | `telegram-vps-egress` (`telegram_vps_egress_subnet`) |
| Proxy IP | `telegram_vps_egress_proxy_ip` |

## Deploy order

```bash
cd /ansible && source .env.vault

# 1. Proxy (once, or after VPS backend changes)
./scripts/run/run_telegram_vps_egress.sh --preprod --limit estate-preprod-gitlab

# 2. Rebuild application compose (attach network + extra_hosts)
./scripts/run/run_docker_app.sh deploy cert-monitoring --preprod --limit estate-preprod-gitlab
./scripts/run/run_docker_app.sh deploy cert-orchestrator --preprod --limit estate-preprod-gitlab
```

Prod: `--prod --limit estate-prod-gitlab` (cert-monitoring, cloud-hibernate-operator).

## Client vars (docker_app)

In `group_vars/<service>.yml` inside `docker_app` (no references to `telegram_vps_egress_*`):

```yaml
docker_app:
  telegram_egress:
    enabled: true
    network_name: telegram-vps-egress
    extra_hosts:
      - name: api.telegram.org
        ip: 172.30.100.2
```

When changing subnet/proxy IP in egress: update `extra_hosts` in each service separately.

## Diagram

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

## Check

```bash
docker ps --filter name=telegram-vps-egress
docker network inspect telegram-vps-egress
docker exec cert-monitoring getent hosts api.telegram.org
# 172.30.100.2  api.telegram.org

docker exec cert-monitoring curl -sv --max-time 15 \
  https://api.telegram.org/bot<TOKEN>/getMe 2>&1 | tail -15
```

## Rollback

1. In service group_vars: `telegram_egress.enabled: false`, and if needed legacy `docker_app_telegram_vps_enabled: true`.
2. Redeploy docker_app.
3. Stop the proxy: `docker compose -f /docker/apps/telegram-vps-egress/docker-compose.yml down`

See also: `roles/telegram_vps_egress/README.md`, `DOCKER_APPS.md`
