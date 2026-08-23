# Docker apps: secrets in Vault

Secrets are **not** in git. Role `docker_app` reads KV via `vault_kv2_get` and writes **`/docker/apps/<slug>/.env`** (mode 0600). Compose mounts `env_file: .env`. Non-secret parameters: `config/*.conf` or `config/config.yaml`.

## Path in Vault

| Parameter | Value |
|----------|----------|
| Mount (engine) | `ansible` (`docker_app_vault_mount_point`) |
| Path | service name (`docker_app_vault_path`) |

CLI (prod):

```bash
export VAULT_ADDR=https://vault.example.com
vault kv put ansible/cert-monitoring TELEGRAM_BOT_TOKEN="<token>"
vault kv put ansible/cert-orchestrator TELEGRAM_BOT_TOKEN="..." TELEGRAM_CHAT_IDS="..." REG_RU_DNS_USERNAME="..." REG_RU_DNS_PASSWORD="..." ssh_private_key=@id_estate.pem
vault kv put ansible/cloud-hibernate-operator TELEGRAM_BOT_TOKEN="..." IAM_PASSWORD="..." API_KEYS="chk_..."
```

Preprod: `VAULT_ADDR=https://vault.preprod.example.com`, same paths (`cert-monitoring`, `cert-orchestrator`, …).

## Key names in group_vars

`group_vars/<service>.yml` sets **`docker_app_vault_key_map`**: logical name (for templates) → field name in the Vault secret.

Example `group_vars/cert-monitoring.yml`:

```yaml
docker_app_vault_mount_point: ansible
docker_app_vault_path: cert-monitoring
docker_app_vault_key_map:
  TELEGRAM_BOT_TOKEN: TELEGRAM_BOT_TOKEN
```

### cert-monitoring

| Vault key | Required | In group_vars (not a secret) |
|-----------|-------------|--------------------------|
| `TELEGRAM_BOT_TOKEN` | yes | `telegram_chat_ids`, `monitored_hosts`, intervals, … |

### cert-orchestrator

| Vault key | Required |
|-----------|-------------|
| `TELEGRAM_BOT_TOKEN` | yes |
| `TELEGRAM_CHAT_IDS` | yes (example: `-1000000000001`) |
| `REG_RU_DNS_USERNAME` | yes |
| `REG_RU_DNS_PASSWORD` | yes |
| `ssh_private_key` | yes → `/docker/apps/cert-orchestrator/.ssh/id_estate` (0600), mount in the container `/ssh/id_estate:ro` |
| `K8S_TOKEN` | yes → `.env` (ServiceAccount token for kubectl) |
| `k8s_ca_cert` | yes → `/docker/apps/cert-orchestrator/.k8s/ca.crt`, mount `/run/cert-orchestrator/k8s-ca.crt:ro` |

Orchestrator secrets in `.env`: `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_IDS`, `REG_RU_DNS_USERNAME`, `REG_RU_DNS_PASSWORD`, `K8S_TOKEN`.

K8s: `kubernetes.api_server` and `cert_orchestrator_k8s_namespace_secrets` in `group_vars/cert-orchestrator.yml` (no kubeconfig mount).
SSH nginx targets (`target_nginx_hosts`): gitlab-nginx, **edge-lb** (`/docker/apps/edge-lb/certs`, vhost vault + hsm-adapter). The hsm-adapter VM is not in targets.
RBAC and token issue: **`CERT_ORCHESTRATOR_K8S_RBAC.md`**.

### cloud-hibernate-operator

| Vault key | Destination on the host |
|-----------|---------------|
| `TELEGRAM_BOT_TOKEN` | `.env` |
| `IAM_PASSWORD` | `.env` |
| `API_KEYS` | `.env` (when `api_auth_enabled: true`) |

The rest: `group_vars/cloud-hibernate-operator.yml` (IAM username, endpoints, clusters_config, …).

### hsm-adapter (treasury-hsm-adapter)

Mount **`secret`** (not `ansible`), path **`treasury-hsm-adapter`**. Key in Vault UI: [secret/kv/treasury-hsm-adapter](https://vault.example.com/ui/vault/secrets/secret/kv/treasury-hsm-adapter).

| Vault key | Destination on the host |
|-----------|---------------|
| `external_csp_license` | `.env` → `EXTERNAL_CSP_LICENSE` in the hsm-adapter container |

Example `group_vars/hsm-adapter.yml`:

```yaml
docker_app_vault_mount_point: secret
docker_app_vault_path: treasury-hsm-adapter
docker_app_vault_key_map:
  EXTERNAL_CSP_LICENSE: external_csp_license
```

CLI (prod):

```bash
export VAULT_ADDR=https://vault.example.com
vault kv put secret/treasury-hsm-adapter external_csp_license="<license>"
```

Preprod: `VAULT_ADDR=https://vault.preprod.example.com`, same path.

The rest (images, logging, data dirs): `group_vars/hsm-adapter.yml`. TLS: **edge-lb** vhost `hsm-adapter` (`group_vars/edge-lb.yml`).

### treasury-policy-gateway

Mount **`secret`**, path **`treasury-policy-gateway-app`** (same as ESO preprod).

| Vault key | Destination on the host |
|-----------|---------------|
| `kafkaClientPassword` | `.env` → `KAFKA_CLIENT_PASSWORD` |
| `file-storage.s3.accessKey` | `FILE_STORAGE_S3_ACCESS_KEY` |
| `file-storage.s3.secretKey` | `FILE_STORAGE_S3_SECRET_KEY` |
| `treasury.policy-gateway.dgtry.pin` | literal in `docker-compose.yml`: **`treasury.policy-gateway.dgtry.pin`** (same as ESO/k8s, lowercase; `$` → `$$`, yaml single quotes) |
| `EXTERNAL_CSP_LICENSE` | `EXTERNAL_CSP_LICENSE` |
| `spring.kafka.properties.ssl.truststore.password` | Kafka JKS truststore/keystore password (init + Spring SSL + `JAVA_TOOL_OPTIONS`) |

Extra path (same as ESO preprod for `kafkaClientPassword`):

| Path | Vault key | → `.env` |
|------|-----------|----------|
| `secret/treasury-kafka` | `kafkaClientPassword` | `KAFKA_CLIENT_PASSWORD` |

Set via `docker_app_vault_extra_reads` in `group_vars/treasury-policy-gateway.yml`.

Kafka CA (truststore init): file `roles/docker_app/files/treasury-policy-gateway/kafka-ca-prod.crt` (chain from k8s Secret `kafka-ca-cert`, platform), not Vault. Update: `(local notes omitted)`.

Example `group_vars/treasury-policy-gateway.yml`: see `docker_app_vault_key_map` in the repository.

CLI (prod):

```bash
export VAULT_ADDR=https://vault.example.com
vault kv put secret/treasury-policy-gateway-app \
  file-storage.s3.accessKey="..." \
  file-storage.s3.secretKey="..." \
  treasury.policy-gateway.dgtry.pin="..." \
  EXTERNAL_CSP_LICENSE="..."
# KAFKA_CLIENT_PASSWORD: already in secret/treasury-kafka (ansible pulls extra_reads)
```

Preprod: same path, `VAULT_ADDR=https://vault.preprod.example.com`. Keys are **not** in Vault: directory `data/cprocsp/keys` on the VM (manual copy from hsm-adapter).

### cryptopro

Mount **`secret`**, path **`cryptopro-service-app`**.

| Vault key | Destination on the host |
|-----------|---------------|
| `spring.datasource.username` | `SPRING_DATASOURCE_USERNAME` |
| `spring.datasource.password` | `SPRING_DATASOURCE_PASSWORD` |
| `spring.flyway.user` | `SPRING_FLYWAY_USER` |
| `spring.flyway.password` | `SPRING_FLYWAY_PASSWORD` |

Example `group_vars/cryptopro.yml`: see `docker_app_vault_key_map`.

CLI (prod):

```bash
export VAULT_ADDR=https://vault.example.com
vault kv put secret/cryptopro-service-app \
  spring.datasource.username="..." \
  spring.datasource.password="..." \
  spring.flyway.user="..." \
  spring.flyway.password="..."
```

Signing certificate (escrow / CryptoPro): via Swagger **after** deploy (`importCertificate`), not via Vault in this playbook.

## Run after writing secrets

```bash
./scripts/run/run_docker_app.sh deploy cert-monitoring --prod --limit estate-prod-gitlab --ssh-agent
./scripts/run/run_docker_app.sh deploy cert-orchestrator --preprod --limit estate-preprod-gitlab --ssh-agent
./scripts/run/run_docker_app.sh deploy cloud-hibernate-operator --prod --limit estate-prod-gitlab --ssh-agent
./scripts/run/run_docker_app.sh deploy hsm-adapter --prod --limit estate-prod-cryptopro-01 --ssh-agent
./scripts/run/run_docker_app.sh deploy treasury-policy-gateway --prod --limit estate-prod-cryptopro-01 --ssh-agent
./scripts/run/run_docker_app.sh deploy cryptopro --prod --limit estate-prod-cryptopro-01 --ssh-agent
./scripts/run/run_docker_app.sh deploy hsm-adapter --preprod --limit estate-preprod-hsm-adapter --ssh-agent
```

See also: `docs/DOCKER_APPS.md`, `docs/VAULT_INTEGRATION.md`
