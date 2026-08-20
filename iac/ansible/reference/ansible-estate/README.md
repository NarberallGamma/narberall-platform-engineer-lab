# Estate Ansible (Huawei-class compute)

**Business first:** after compute exists, apps and Vault are a playbook limit, and idle non-prod **parks at night**. Not a second Terraform catalog. Buyer FinOps: [`../../../../architecture/02-finops-night-park.md`](../../../../architecture/02-finops-night-park.md).

Sanitized Ansible tree for a **Huawei-class estate**. I used this on cloud.ru Advanced (Huawei Cloud class) after compute already existed: prepare hosts, ship Docker apps, park idle CCE/ECS at night, scrape node-exporter, stand up Vault, and grant RDS users / Flyway. PREPROD is the same tree (not published twice).

This runs on **living VMs**, not empty-VPS bootstrap. Host baseline for a new box stays in [`../ansible-bootstrap/`](../ansible-bootstrap/). Hunter map: [`../`](../). Case: [`../../../../case-studies/10-ansible-estate.md`](../../../../case-studies/10-ansible-estate.md). Terraform catalog: [`../../../../case-studies/07-huawei-compute-catalog.md`](../../../../case-studies/07-huawei-compute-catalog.md). Night park: [`../../../../architecture/02-finops-night-park.md`](../../../../architecture/02-finops-night-park.md). Compute code: [`../../../terraform/cloud-ru-compute/`](../../../terraform/cloud-ru-compute/).

Brand, live IPs, Vault tokens, EDR packages, and TLS keys are stripped. Role logic, Jinja, migrate playbooks, and the nested database tree stay almost intact so a reviewer can parse a real estate operator kit, not a three-task demo.

```text
ansible-estate/
  playbooks/
    prepare_servers.yml prepare_vps_cluster.yml
    docker_app_edge_lb.yml docker_app_cryptopro.yml
    docker_app_cloud_hibernate_operator.yml
    docker_app_{cert-monitoring,cert-orchestrator,gitlab-nginx,hsm-adapter,treasury-policy-gateway}.yml
    migrate_edge_lb_legacy.yml migrate_gitlab_nginx_legacy.yml migrate_hsm_adapter_legacy.yml
    vault-deploy-*.yml vault-init-*.yml vault-secrets-*.yml
    node-exporter-deploy.yml telegram_vps_egress.yml
    setup_bootstrap_users.yml setup_cert_orchestrator_ssh_user.yml
    estate_databases/          # RDS users + schema_flyway (was nested DB tree)
  roles/
    prepare_servers prepare_nvidia_gpu prepare_vps_cluster
    docker_app node-exporter telegram_vps_egress
    vault-docker vault-loadbalancer vault-secrets
  inventories/{prod,preprod,demo,localhost}/hosts.ini.example
  group_vars/                  # one file per docker_app + Vault prod/preprod
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| `prepare_servers` | Timezone, apt, AD/SSSD, Docker CE migrate, optional NVIDIA CDI, optional EDR. Flags in `group_vars/prepare_servers.yml`. |
| `docker_app` | One slug, one compose tree under `/docker/apps/<slug>`. Vault KV → `.env`. Extra tasks for edge-lb, HSM, CryptoPro, treasury gateway. |
| `edge-lb` | nginx + keepalived VIP + Vault active-leader sidecar. Legacy migrate playbook keeps the cutover. |
| `cloud-hibernate-operator` | Night-park job: stop non-prod CCE/ECS on a calendar. Same idea as the FinOps page. |
| Vault trio | DEMO-era HA: Raft nodes, nginx/keepalived LB, secret load. Playbooks under `playbooks/vault-*.yml`. |
| `estate_databases` | RDS PostgreSQL as code: restore/recreate; **`schema_flyway`** owns DDL (Flyway); app role gets DML + `REPLICATION` (Debezium); extra **RO** (audit/BI) and **RW** (tools) grants; **drop** revokes without REASSIGN. Same tree as the docker apps. |
| `node-exporter` + Telegram egress | Host metrics compose; Envoy sidecar so bots leave via VPS, not the estate SNAT. |

```bash
cp inventories/prod/hosts.ini.example inventories/prod/hosts.ini
# place TLS under artifacts/ only on the control node (gitignored)
ansible-galaxy collection install -r requirements.yml
./scripts/run/run_prepare_servers.sh --prod --limit estate-prod-gitlab
./scripts/run/run_docker_app.sh deploy edge-lb --prod --limit estate-prod-lb-1
./scripts/run/run_docker_app.sh deploy cloud-hibernate-operator --prod --limit estate-prod-gitlab
./scripts/prod/run-vault.sh deploy
./scripts/run/run_schema_flyway_setup.sh treasury_contract
```

## Playbooks

| Playbook | Scope |
|----------|-------|
| `prepare_servers.yml` | Host baseline on `[prepare]` |
| `prepare_vps_cluster.yml` | VPS Envoy egress cluster |
| `docker_app_edge_lb.yml` | VIP nginx / keepalived |
| `docker_app_cryptopro.yml` | CryptoPro signing service on the HSM VM |
| `docker_app_hsm_adapter.yml` / `docker_app_treasury_policy_gateway.yml` | HSM adapter and treasury policy API |
| `docker_app_cloud_hibernate_operator.yml` | Night-park operator |
| `docker_app_cert_monitoring.yml` / `docker_app_cert_orchestrator.yml` | Wildcard TLS watch + k8s/SSH deploy |
| `docker_app_gitlab_nginx.yml` | GitLab / registry TLS front |
| `migrate_*_legacy.yml` | Host nginx → compose cutover |
| `vault-deploy-*.yml` / `vault-init-*.yml` / `vault-secrets-*.yml` | Vault HA + secret load |
| `node-exporter-deploy.yml` | Host metrics |
| `telegram_vps_egress.yml` | Envoy to Telegram API via VPS |
| `estate_databases/playbooks/*.yaml` | RDS restore, RO/RW users, schema Flyway |

## Roles

| Role | Job |
|------|-----|
| `prepare_servers` | OS, DNS/AD, Docker CE, optional GPU, optional EDR |
| `prepare_nvidia_gpu` | Driver, Container Toolkit, CDI, `docker run --gpus all` |
| `prepare_vps_cluster` | Admin user, chrony, firewall, Envoy |
| `docker_app` | Vault check/load, render compose, per-slug extras |
| `vault-docker` / `vault-loadbalancer` / `vault-secrets` | Raft Vault, VIP nginx, KV seed |
| `node-exporter` | Compose exporter |
| `telegram_vps_egress` | Isolated Docker net + Envoy |
| `estate_databases` roles `db` / `ro_user` / `rw_user` / `schema_flyway` / `drop_db_user` | PostgreSQL grants and Flyway owner |

## Inventory contract

- Envs: `inventories/prod`, `preprod`, `demo`, `localhost` (copy `hosts.ini.example` → `hosts.ini`)
- Groups stay full: `vault_cluster`, `vault_lb`, `edge_lb`, `cryptopro_vm`, `hsm_adapter`, `gitlab`, `vps_cluster`, `prepare`, and the docker_app groups
- Secrets: Vault token on the control node (`.env.vault`, gitignored). No live token in `group_vars`.
- TLS names: `example.com` / `preprod.example.com` under local `artifacts/`
- Images: `registry.example.com/platform/base-images`

## Keywords

Ansible, Docker Compose, Vault Raft, keepalived, nginx, CryptoPro, HSM, Teleport, NVIDIA, GitLab, night park, FinOps, RDS PostgreSQL, Flyway, Huawei-class, cloud.ru, node-exporter, Telegram egress
