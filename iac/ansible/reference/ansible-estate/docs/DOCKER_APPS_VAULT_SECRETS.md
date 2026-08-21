# Docker apps: секреты в Vault

Секреты **не** в git. Роль `docker_app` читает KV через `vault_kv2_get` и записывает в **`/docker/apps/<slug>/.env`** (mode 0600). Compose подключает `env_file: .env`. Несекретные параметры: `config/*.conf` или `config/config.yaml`.

## Путь в Vault

| Параметр | Значение |
|----------|----------|
| Mount (engine) | `ansible` (`docker_app_vault_mount_point`) |
| Path | имя сервиса (`docker_app_vault_path`) |

CLI (prod):

```bash
export VAULT_ADDR=https://vault.example.com
vault kv put ansible/cert-monitoring TELEGRAM_BOT_TOKEN="<token>"
vault kv put ansible/cert-orchestrator TELEGRAM_BOT_TOKEN="..." TELEGRAM_CHAT_IDS="..." REG_RU_DNS_USERNAME="..." REG_RU_DNS_PASSWORD="..." ssh_private_key=@id_estate.pem
vault kv put ansible/cloud-hibernate-operator TELEGRAM_BOT_TOKEN="..." IAM_PASSWORD="..." API_KEYS="chk_..."
```

Preprod: `VAULT_ADDR=https://vault.preprod.example.com`, те же path (`cert-monitoring`, `cert-orchestrator`, …).

## Имена ключей в group_vars

В `group_vars/<service>.yml` задаётся **`docker_app_vault_key_map`**: logical name (для templates) → имя поля в секрете Vault.

Пример `group_vars/cert-monitoring.yml`:

```yaml
docker_app_vault_mount_point: ansible
docker_app_vault_path: cert-monitoring
docker_app_vault_key_map:
  TELEGRAM_BOT_TOKEN: TELEGRAM_BOT_TOKEN
```

### cert-monitoring

| Vault key | Обязательно | В group_vars (не секрет) |
|-----------|-------------|--------------------------|
| `TELEGRAM_BOT_TOKEN` | да | `telegram_chat_ids`, `monitored_hosts`, intervals, … |

### cert-orchestrator

| Vault key | Обязательно |
|-----------|-------------|
| `TELEGRAM_BOT_TOKEN` | да |
| `TELEGRAM_CHAT_IDS` | да (пример: `-1000000000001`) |
| `REG_RU_DNS_USERNAME` | да |
| `REG_RU_DNS_PASSWORD` | да |
| `ssh_private_key` | да → `/docker/apps/cert-orchestrator/.ssh/id_estate` (0600), mount в контейнер `/ssh/id_estate:ro` |
| `K8S_TOKEN` | да → `.env` (ServiceAccount token для kubectl) |
| `k8s_ca_cert` | да → `/docker/apps/cert-orchestrator/.k8s/ca.crt`, mount `/run/cert-orchestrator/k8s-ca.crt:ro` |

Секреты оркестратора в `.env`: `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_IDS`, `REG_RU_DNS_USERNAME`, `REG_RU_DNS_PASSWORD`, `K8S_TOKEN`.

K8s: `kubernetes.api_server` и `cert_orchestrator_k8s_namespace_secrets` в `group_vars/cert-orchestrator.yml` (без kubeconfig mount).
SSH nginx targets (`target_nginx_hosts`): gitlab-nginx, **edge-lb** (`/docker/apps/edge-lb/certs`, vhost vault + hsm-adapter). VM hsm-adapter не в targets.
RBAC и выпуск токена: **`CERT_ORCHESTRATOR_K8S_RBAC.md`**.

### cloud-hibernate-operator

| Vault key | Куда на хосте |
|-----------|---------------|
| `TELEGRAM_BOT_TOKEN` | `.env` |
| `IAM_PASSWORD` | `.env` |
| `API_KEYS` | `.env` (при `api_auth_enabled: true`) |

Остальное: `group_vars/cloud-hibernate-operator.yml` (IAM username, endpoints, clusters_config, …).

### hsm-adapter (treasury-hsm-adapter)

Mount **`secret`** (не `ansible`), path **`treasury-hsm-adapter`**. Ключ в Vault UI: [secret/kv/treasury-hsm-adapter](https://vault.example.com/ui/vault/secrets/secret/kv/treasury-hsm-adapter).

| Vault key | Куда на хосте |
|-----------|---------------|
| `external_csp_license` | `.env` → `EXTERNAL_CSP_LICENSE` в контейнере hsm-adapter |

Пример `group_vars/hsm-adapter.yml`:

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

Preprod: `VAULT_ADDR=https://vault.preprod.example.com`, тот же path.

Остальное (образы, logging, data dirs): `group_vars/hsm-adapter.yml`. TLS: **edge-lb** vhost `hsm-adapter` (`group_vars/edge-lb.yml`).

### treasury-policy-gateway

Mount **`secret`**, path **`treasury-policy-gateway-app`** (как ESO preprod).

| Vault key | Куда на хосте |
|-----------|---------------|
| `kafkaClientPassword` | `.env` → `KAFKA_CLIENT_PASSWORD` |
| `file-storage.s3.accessKey` | `FILE_STORAGE_S3_ACCESS_KEY` |
| `file-storage.s3.secretKey` | `FILE_STORAGE_S3_SECRET_KEY` |
| `treasury.policy-gateway.dgtry.pin` | literal в `docker-compose.yml`: **`treasury.policy-gateway.dgtry.pin`** (как ESO/k8s, lowercase; `$` → `$$`, yaml single quotes) |
| `EXTERNAL_CSP_LICENSE` | `EXTERNAL_CSP_LICENSE` |
| `spring.kafka.properties.ssl.truststore.password` | Kafka JKS truststore/keystore password (init + Spring SSL + `JAVA_TOOL_OPTIONS`) |

Доп. path (как ESO preprod для `kafkaClientPassword`):

| Path | Vault key | → `.env` |
|------|-----------|----------|
| `secret/treasury-kafka` | `kafkaClientPassword` | `KAFKA_CLIENT_PASSWORD` |

Задаётся `docker_app_vault_extra_reads` в `group_vars/treasury-policy-gateway.yml`.

Kafka CA (truststore init): файл `roles/docker_app/files/treasury-policy-gateway/kafka-ca-prod.crt` (цепочка из k8s Secret `kafka-ca-cert`, platform), не Vault. Обновление: `(local notes omitted)`.

Пример `group_vars/treasury-policy-gateway.yml`: см. `docker_app_vault_key_map` в репозитории.

CLI (prod):

```bash
export VAULT_ADDR=https://vault.example.com
vault kv put secret/treasury-policy-gateway-app \
  file-storage.s3.accessKey="..." \
  file-storage.s3.secretKey="..." \
  treasury.policy-gateway.dgtry.pin="..." \
  EXTERNAL_CSP_LICENSE="..."
# KAFKA_CLIENT_PASSWORD: уже в secret/treasury-kafka (ansible подтягивает extra_reads)
```

Preprod: path тот же, `VAULT_ADDR=https://vault.preprod.example.com`. Keys **не** в Vault: каталог `data/cprocsp/keys` на VM (ручной перенос с hsm-adapter).

### cryptopro

Mount **`secret`**, path **`cryptopro-service-app`**.

| Vault key | Куда на хосте |
|-----------|---------------|
| `spring.datasource.username` | `SPRING_DATASOURCE_USERNAME` |
| `spring.datasource.password` | `SPRING_DATASOURCE_PASSWORD` |
| `spring.flyway.user` | `SPRING_FLYWAY_USER` |
| `spring.flyway.password` | `SPRING_FLYWAY_PASSWORD` |

Пример `group_vars/cryptopro.yml`: см. `docker_app_vault_key_map`.

CLI (prod):

```bash
export VAULT_ADDR=https://vault.example.com
vault kv put secret/cryptopro-service-app \
  spring.datasource.username="..." \
  spring.datasource.password="..." \
  spring.flyway.user="..." \
  spring.flyway.password="..."
```

Сертификат подписи (escrow / CryptoPro): через Swagger **после** deploy (`importCertificate`), не через Vault в этом playbook.

## Запуск после записи секретов

```bash
./scripts/run/run_docker_app.sh deploy cert-monitoring --prod --limit estate-prod-gitlab --ssh-agent
./scripts/run/run_docker_app.sh deploy cert-orchestrator --preprod --limit estate-preprod-gitlab --ssh-agent
./scripts/run/run_docker_app.sh deploy cloud-hibernate-operator --prod --limit estate-prod-gitlab --ssh-agent
./scripts/run/run_docker_app.sh deploy hsm-adapter --prod --limit estate-prod-cryptopro-01 --ssh-agent
./scripts/run/run_docker_app.sh deploy treasury-policy-gateway --prod --limit estate-prod-cryptopro-01 --ssh-agent
./scripts/run/run_docker_app.sh deploy cryptopro --prod --limit estate-prod-cryptopro-01 --ssh-agent
./scripts/run/run_docker_app.sh deploy hsm-adapter --preprod --limit estate-preprod-hsm-adapter --ssh-agent
```

См. также: `docs/DOCKER_APPS.md`, `docs/VAULT_INTEGRATION.md`
