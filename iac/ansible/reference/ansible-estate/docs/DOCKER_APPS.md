# Docker apps: деплой через Ansible

Роль **`docker_app`**: одно compose-приложение в **`/docker/apps/<slug>/`** на **любой** VM из inventory.

## Плейбуки, inventory и group_vars

| App | Playbook | Inventory group | group_vars |
|-----|----------|-----------------|------------|
| cert-monitoring | `playbooks/docker_app_cert_monitoring.yml` | `[cert_monitoring]` | `group_vars/cert-monitoring.yml` |
| cert-orchestrator | `playbooks/docker_app_cert_orchestrator.yml` | `[cert_orchestrator]` | `group_vars/cert-orchestrator.yml` |
| cloud-hibernate-operator | `playbooks/docker_app_cloud_hibernate_operator.yml` | `[cloud_hibernate_operator]` | `group_vars/cloud-hibernate-operator.yml` |
| **Telegram VPS proxy** | `playbooks/telegram_vps_egress.yml` | `[telegram_vps_egress]` | `group_vars/telegram_vps_egress.yml` (отдельно от docker_app) |
| gitlab-nginx | `playbooks/docker_app_gitlab_nginx.yml` | `[gitlab_nginx]` | `group_vars/gitlab-nginx.yml` |
| edge-lb | `playbooks/docker_app_edge_lb.yml` | `[edge_lb]` | `group_vars/edge-lb.yml` |
| hsm-adapter | `playbooks/docker_app_hsm_adapter.yml` | `[hsm_adapter]` → `[cryptopro_vm]` | `group_vars/hsm-adapter.yml` |
| treasury-policy-gateway | `playbooks/docker_app_treasury_policy_gateway.yml` | `[cryptopro_vm]` | `group_vars/treasury-policy-gateway.yml` |
| cryptopro | `playbooks/docker_app_cryptopro.yml` | `[cryptopro_vm]` | `group_vars/cryptopro.yml` |

Legacy-миграция GitLab Omnibus TLS → gitlab-nginx: `playbooks/migrate_gitlab_nginx_legacy.yml`
(скрипт `scripts/run/run_migrate_gitlab_nginx_legacy.sh`). Migrate завершён; переключатель `gitlab_nginx_legacy_migration_enabled: false` в group_vars.

Legacy-миграция host nginx/keepalived → docker edge-lb: `playbooks/migrate_edge_lb_legacy.yml`
(скрипт `scripts/run/run_migrate_edge_lb_legacy.sh`). Migrate завершён (preprod + prod lb-1/lb-2).
Переключатель `edge_lb_legacy_migration_enabled: false` в group_vars/edge-lb.yml.
При повторном migrate на prod: **lb-2** (BACKUP), затем **lb-1** (MASTER).
После ansible на LB: post-check с паузой ~90 с (cooldown SSH).

Legacy-миграция hsm-adapter + apt nginx на хосте -> docker_app hsm-adapter (TLS на **edge-lb**): `playbooks/migrate_hsm_adapter_legacy.yml`
(скрипт `scripts/run/run_migrate_hsm_adapter_legacy.sh`). Переключатель `hsm_adapter_legacy_migration_enabled` в group_vars.
Перед migrate: deploy **edge-lb** с vhost `hsm-adapter` на LB. TLS только на edge-lb.
Секрет `EXTERNAL_CSP_LICENSE`: Vault mount **`secret`**, path **`treasury-hsm-adapter`** (см. **`DOCKER_APPS_VAULT_SECRETS.md`**).

**edge-lb (из опыта migrate):** nginx OSS `proxy_next_upstream` без `http_501/472/474`;
keepalived osixia mount `./config/keepalived` → `/container/service/keepalived/assets` + `notify.sh`;
active upstream: `config/vault_upstream/vault_active_upstream.conf` (не в `conf.d/`);
cert-orchestrator `ssl_dir`: `/docker/apps/edge-lb/certs` (legacy `/etc/nginx/ssl` на LB снят).
HSM adapter: `conf.d/hsm-adapter.conf`, backend `edge_lb_hsm_adapter_backend` (private IP hsm-adapter VM).

Добавить хост в нужную группу в `inventories/*/hosts.ini`:

```ini
[cert_monitoring]
estate-prod-gitlab
some-other-host
```

Конфиг приложения и **имена ключей Vault** (не значения): `group_vars/<service>.yml`.  
Плейбук подключает файл через **`vars_files`** (как `prepare_vps_cluster.yml`), иначе при `-i inventories/prod/hosts.ini` корневой `group_vars/` не подхватывается автоматически.

## Запуск с control node (`/ansible` на GitLab)

SSH: пользователь **`ansible`**, ключ **`/ansible/.ssh/ansible_ssh_key`** (CI), `become: true` в плейбуке.  
Задано в `host_vars/estate-prod-gitlab.yml` / `host_vars/estate-preprod-gitlab.yml`.

```bash
cd /ansible
source .env.vault   # VAULT_ADDR + VAULT_TOKEN

# Prod (estate-prod-gitlab)
./scripts/run/run_docker_app.sh deploy cert-monitoring --prod --limit estate-prod-gitlab
./scripts/run/run_docker_app.sh deploy cloud-hibernate-operator --prod --limit estate-prod-gitlab
./scripts/run/run_docker_app.sh deploy gitlab-nginx --prod --limit estate-prod-gitlab
./scripts/run/run_docker_app.sh deploy edge-lb --prod --limit estate-prod-lb-1
./scripts/run/run_docker_app.sh deploy edge-lb --prod --limit estate-prod-lb-2
./scripts/run/run_docker_app.sh deploy hsm-adapter --prod --limit estate-prod-cryptopro-01
./scripts/run/run_docker_app.sh deploy treasury-policy-gateway --prod --limit estate-prod-cryptopro-01
./scripts/run/run_docker_app.sh deploy cryptopro --prod --limit estate-prod-cryptopro-01

# Preprod (estate-preprod-gitlab, отдельный clone /ansible)
./scripts/run/run_docker_app.sh deploy cert-orchestrator --preprod --limit estate-preprod-gitlab
./scripts/run/run_docker_app.sh deploy cert-monitoring --preprod --limit estate-preprod-gitlab
./scripts/run/run_docker_app.sh deploy gitlab-nginx --preprod --limit estate-preprod-gitlab
./scripts/run/run_docker_app.sh deploy edge-lb --preprod --limit estate-preprod-lb-1
./scripts/run/run_docker_app.sh deploy hsm-adapter --preprod --limit estate-preprod-hsm-adapter

# Legacy: hsm-adapter (preprod первым; edge-lb с hsm-adapter vhost уже выложен)
./scripts/run/run_migrate_hsm_adapter_legacy.sh --preprod --limit estate-preprod-hsm-adapter --ssh-key ~/.ssh/estate-preprod-ecs-key.pem

# Legacy: первичная миграция TLS GitLab -> gitlab-nginx (один раз)
./scripts/run/run_migrate_gitlab_nginx_legacy.sh --preprod --limit estate-preprod-gitlab
./scripts/run/run_migrate_gitlab_nginx_legacy.sh --prod --limit estate-prod-gitlab

# Legacy: host nginx/keepalived -> docker edge-lb (prod: lb-2, затем lb-1)
./scripts/run/run_migrate_edge_lb_legacy.sh --preprod --limit estate-preprod-lb-1 --ssh-key ~/.ssh/estate-preprod-ecs-key.pem
./scripts/run/run_migrate_edge_lb_legacy.sh --prod --limit estate-prod-lb-2 --ssh-key ~/.ssh/estate-prod-ecs-key.pem
./scripts/run/run_migrate_edge_lb_legacy.sh --prod --limit estate-prod-lb-1 --ssh-key ~/.ssh/estate-prod-ecs-key.pem
```

Секреты: Vault mount **`ansible`** (или **`secret`** для hsm-adapter), path по сервису (см. **`DOCKER_APPS_VAULT_SECRETS.md`**).
Telegram через VPS: сначала **`run_telegram_vps_egress.sh`**, затем redeploy apps. Клиентские vars: **`docker_app.telegram_egress`** в `group_vars/<service>.yml` (без `vars_files` egress). См. **`TELEGRAM_VPS_EGRESS_GITLAB.md`**.
gitlab-nginx Vault не использует; TLS в `certs/` (cert-orchestrator или legacy-миграция).

## Типичное размещение (inventory 2026-06-17)

| Окружение | cert-monitoring | cert-orchestrator | cloud-hibernate-operator | gitlab-nginx |
|-----------|-----------------|-------------------|--------------------------|--------------|
| Preprod | estate-preprod-gitlab | estate-preprod-gitlab | не деплоен | estate-preprod-gitlab |
| Prod | estate-prod-gitlab | не деплоен | estate-prod-gitlab | estate-prod-gitlab |

См. также: `roles/docker_app/README.md`, `TELEGRAM_VPS_EGRESS_GITLAB.md`
