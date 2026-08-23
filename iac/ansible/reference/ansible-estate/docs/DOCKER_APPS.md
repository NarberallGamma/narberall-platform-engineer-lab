# Docker apps: deploy via Ansible

Role **`docker_app`**: one compose application under **`/docker/apps/<slug>/`** on **any** VM from inventory.

## Playbooks, inventory, and group_vars

| App | Playbook | Inventory group | group_vars |
|-----|----------|-----------------|------------|
| cert-monitoring | `playbooks/docker_app_cert_monitoring.yml` | `[cert_monitoring]` | `group_vars/cert-monitoring.yml` |
| cert-orchestrator | `playbooks/docker_app_cert_orchestrator.yml` | `[cert_orchestrator]` | `group_vars/cert-orchestrator.yml` |
| cloud-hibernate-operator | `playbooks/docker_app_cloud_hibernate_operator.yml` | `[cloud_hibernate_operator]` | `group_vars/cloud-hibernate-operator.yml` |
| **Telegram VPS proxy** | `playbooks/telegram_vps_egress.yml` | `[telegram_vps_egress]` | `group_vars/telegram_vps_egress.yml` (separate from docker_app) |
| gitlab-nginx | `playbooks/docker_app_gitlab_nginx.yml` | `[gitlab_nginx]` | `group_vars/gitlab-nginx.yml` |
| edge-lb | `playbooks/docker_app_edge_lb.yml` | `[edge_lb]` | `group_vars/edge-lb.yml` |
| hsm-adapter | `playbooks/docker_app_hsm_adapter.yml` | `[hsm_adapter]` → `[cryptopro_vm]` | `group_vars/hsm-adapter.yml` |
| treasury-policy-gateway | `playbooks/docker_app_treasury_policy_gateway.yml` | `[cryptopro_vm]` | `group_vars/treasury-policy-gateway.yml` |
| cryptopro | `playbooks/docker_app_cryptopro.yml` | `[cryptopro_vm]` | `group_vars/cryptopro.yml` |

Legacy migration GitLab Omnibus TLS → gitlab-nginx: `playbooks/migrate_gitlab_nginx_legacy.yml`
(script `scripts/run/run_migrate_gitlab_nginx_legacy.sh`). Migration is complete; switch `gitlab_nginx_legacy_migration_enabled: false` in group_vars.

Legacy migration host nginx/keepalived → docker edge-lb: `playbooks/migrate_edge_lb_legacy.yml`
(script `scripts/run/run_migrate_edge_lb_legacy.sh`). Migration is complete (preprod + prod lb-1/lb-2).
Switch `edge_lb_legacy_migration_enabled: false` in group_vars/edge-lb.yml.
On a repeat migrate in prod: **lb-2** (BACKUP), then **lb-1** (MASTER).
After ansible on LB: post-check with ~90 s pause (SSH cooldown).

Legacy migration hsm-adapter + apt nginx on the host -> docker_app hsm-adapter (TLS on **edge-lb**): `playbooks/migrate_hsm_adapter_legacy.yml`
(script `scripts/run/run_migrate_hsm_adapter_legacy.sh`). Switch `hsm_adapter_legacy_migration_enabled` in group_vars.
Before migrate: deploy **edge-lb** with vhost `hsm-adapter` on LB. TLS only on edge-lb.
Secret `EXTERNAL_CSP_LICENSE`: Vault mount **`secret`**, path **`treasury-hsm-adapter`** (see **`DOCKER_APPS_VAULT_SECRETS.md`**).

**edge-lb (from migrate experience):** nginx OSS `proxy_next_upstream` without `http_501/472/474`;
keepalived osixia mount `./config/keepalived` → `/container/service/keepalived/assets` + `notify.sh`;
active upstream: `config/vault_upstream/vault_active_upstream.conf` (not in `conf.d/`);
cert-orchestrator `ssl_dir`: `/docker/apps/edge-lb/certs` (legacy `/etc/nginx/ssl` on LB removed).
HSM adapter: `conf.d/hsm-adapter.conf`, backend `edge_lb_hsm_adapter_backend` (private IP of the hsm-adapter VM).

Add the host to the required group in `inventories/*/hosts.ini`:

```ini
[cert_monitoring]
estate-prod-gitlab
some-other-host
```

Application config and **Vault key names** (not values): `group_vars/<service>.yml`.  
The playbook includes the file via **`vars_files`** (same as `prepare_vps_cluster.yml`); otherwise with `-i inventories/prod/hosts.ini` the repo-root `group_vars/` is not picked up automatically.

## Run from the control node (`/ansible` on GitLab)

SSH: user **`ansible`**, key **`/ansible/.ssh/ansible_ssh_key`** (CI), `become: true` in the playbook.  
Set in `host_vars/estate-prod-gitlab.yml` / `host_vars/estate-preprod-gitlab.yml`.

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

# Preprod (estate-preprod-gitlab, separate clone /ansible)
./scripts/run/run_docker_app.sh deploy cert-orchestrator --preprod --limit estate-preprod-gitlab
./scripts/run/run_docker_app.sh deploy cert-monitoring --preprod --limit estate-preprod-gitlab
./scripts/run/run_docker_app.sh deploy gitlab-nginx --preprod --limit estate-preprod-gitlab
./scripts/run/run_docker_app.sh deploy edge-lb --preprod --limit estate-preprod-lb-1
./scripts/run/run_docker_app.sh deploy hsm-adapter --preprod --limit estate-preprod-hsm-adapter

# Legacy: hsm-adapter (preprod first; edge-lb with hsm-adapter vhost already deployed)
./scripts/run/run_migrate_hsm_adapter_legacy.sh --preprod --limit estate-preprod-hsm-adapter --ssh-key ~/.ssh/estate-preprod-ecs-key.pem

# Legacy: initial GitLab TLS migration -> gitlab-nginx (once)
./scripts/run/run_migrate_gitlab_nginx_legacy.sh --preprod --limit estate-preprod-gitlab
./scripts/run/run_migrate_gitlab_nginx_legacy.sh --prod --limit estate-prod-gitlab

# Legacy: host nginx/keepalived -> docker edge-lb (prod: lb-2, then lb-1)
./scripts/run/run_migrate_edge_lb_legacy.sh --preprod --limit estate-preprod-lb-1 --ssh-key ~/.ssh/estate-preprod-ecs-key.pem
./scripts/run/run_migrate_edge_lb_legacy.sh --prod --limit estate-prod-lb-2 --ssh-key ~/.ssh/estate-prod-ecs-key.pem
./scripts/run/run_migrate_edge_lb_legacy.sh --prod --limit estate-prod-lb-1 --ssh-key ~/.ssh/estate-prod-ecs-key.pem
```

Secrets: Vault mount **`ansible`** (or **`secret`** for hsm-adapter), path per service (see **`DOCKER_APPS_VAULT_SECRETS.md`**).
Telegram via VPS: run **`run_telegram_vps_egress.sh`** first, then redeploy apps. Client vars: **`docker_app.telegram_egress`** in `group_vars/<service>.yml` (no egress `vars_files`). See **`TELEGRAM_VPS_EGRESS_GITLAB.md`**.
gitlab-nginx does not use Vault; TLS is in `certs/` (cert-orchestrator or legacy migration).

## Typical placement (inventory 2026-06-17)

| Environment | cert-monitoring | cert-orchestrator | cloud-hibernate-operator | gitlab-nginx |
|-----------|-----------------|-------------------|--------------------------|--------------|
| Preprod | estate-preprod-gitlab | estate-preprod-gitlab | not deployed | estate-preprod-gitlab |
| Prod | estate-prod-gitlab | not deployed | estate-prod-gitlab | estate-prod-gitlab |

See also: `roles/docker_app/README.md`, `TELEGRAM_VPS_EGRESS_GITLAB.md`
