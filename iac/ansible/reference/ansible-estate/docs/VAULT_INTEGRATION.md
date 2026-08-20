# Vault: интеграция с ansible (PROD)

Контрол-нода: каталог **`/ansible`** на **estate-prod-gitlab** после деплоя из Git (ветка `main`).

| Параметр | Значение PROD |
|----------|---------------|
| Vault URL | `https://vault.example.com` |
| KV engines | `ansible/` (cert-*, cloud-hibernate), `secret/` (hsm-adapter и др.) |
| Policy для CI token | `ansible-control` |
| GitLab проект | `platform/ansible` на prod GitLab |
| CI Variables | `VAULT_ADDR`, `VAULT_TOKEN` |

## Как это работает

1. В GitLab CI проекта **ansible** заданы `VAULT_ADDR` и `VAULT_TOKEN`.
2. Пайплайн `deploy-ansible:runner_host` (`common-ci/deploys/ansible-deploy.yaml`) при push в `main` записывает **`/ansible/.env.vault`** (chmod 600, владелец `ansible`).
3. Run-скрипты (`scripts/run/*.sh`) через `scripts/run/lib/control_node_env.sh` выполняют `source .env.vault` и пробрасывают `VAULT_*` в контейнер Ansible.

Файл `.env.vault` в git не хранится (см. `.gitignore`).

## Policy `ansible-control`

Token CI читает секреты из двух KV v2 mount:

| Mount | Примеры path | Зачем |
|-------|--------------|--------|
| **`ansible/`** | `cert-monitoring`, `cert-orchestrator`, `cloud-hibernate-operator` | docker_app в `/docker/apps` |
| **`secret/`** | `treasury-hsm-adapter`, `treasury-*-app` | hsm-adapter и legacy treasury secrets |

Канонический HCL: **`docs/policies/ansible-control.hcl`**.

```hcl
path "ansible/data/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "ansible/metadata/*" {
  capabilities = ["list", "read", "delete"]
}
path "secret/data/*" {
  capabilities = ["read", "list"]
}
path "secret/metadata/*" {
  capabilities = ["read", "list"]
}
```

Создание/обновление через UI: **Policies** → `ansible-control` → Edit ACL Policy.  
CLI (root/admin на **active**-ноде или через API без redirect на `127.0.0.1`):

```bash
export VAULT_ADDR=http://127.0.0.1:8200   # на vault-ноде
export VAULT_TOKEN=<root>
vault policy write ansible-control docs/policies/ansible-control.hcl
```

Изменения policy применяются к уже выданным token сразу (перевыпуск не нужен).

## Выпуск token для GitLab CI

**Web REPL в UI Vault** (`read`, `kv-get`, …) **не поддерживает** `vault token create`. Использовать HTTP API или Vault CLI.

### Способ 1: HTTP API (рекомендуется)

Admin token: UI → иконка пользователя → Copy token, или root из init.

```bash
export VAULT_ADDR=https://vault.example.com
export VAULT_TOKEN=<admin-token>

curl -sS \
  --header "X-Vault-Token: ${VAULT_TOKEN}" \
  --request POST \
  --data '{"policies":["ansible-control"],"period":"768h","display_name":"ansible-gitlab-control-prod","no_default_policy":true}' \
  "${VAULT_ADDR}/v1/auth/token/create" | jq -r '.auth.client_token'
```

Вывод `hvs....` → GitLab **Settings → CI/CD → Variables** → `VAULT_TOKEN` (Mask, Protected).

### Способ 2: Vault CLI

```bash
export VAULT_ADDR=https://vault.example.com
export VAULT_TOKEN=<admin-token>

vault token create \
  -policy=ansible-control \
  -period=768h \
  -display-name="ansible-gitlab-control-prod" \
  -no-default-policy
```

## Быстрая ротация `VAULT_TOKEN` в estate PROD

1. Выпустить новый token (HTTP API или CLI выше). Period `768h` = 32 дня; при необходимости увеличить `period` в JSON.
2. GitLab prod → проект **ansible** → **Settings → CI/CD → Variables** → **`VAULT_TOKEN`** → Edit → вставить новый `hvs....` → Save.
3. Запустить pipeline: push в `main` или **Run pipeline** на ветке `main` (job `deploy-ansible:runner_host`).
4. На **estate-prod-gitlab** проверить:
   ```bash
   sudo ls -la /ansible/.env.vault
   sudo -u ansible grep VAULT_ADDR /ansible/.env.vault
   ```
5. Проверить доступ новым token:
   ```bash
   export VAULT_ADDR=https://vault.example.com
   export VAULT_TOKEN=<новый-token>
   vault kv list ansible/
   ```
6. Отозвать старый token (опционально, после проверки):
   ```bash
   vault token revoke <старый-hvs...>
   ```

Простой push без изменений кода тоже перезапишет `.env.vault`, если переменная в GitLab уже обновлена.

## GitLab CI Variables (PROD ansible)

| Variable | Mask | Protected | Пример |
|----------|------|-----------|--------|
| `VAULT_ADDR` | no | yes | `https://vault.example.com` |
| `VAULT_TOKEN` | yes | yes | `hvs....` (token с policy `ansible-control`) |

Preprod: отдельный token и `https://vault.preprod.example.com` в preprod GitLab.

## Секреты в engine `ansible/`

```bash
vault kv put ansible/example-job db_password="..." api_key="..."
vault kv get ansible/example-job
```

В плейбуке (lookup):

```yaml
- debug:
    msg: "{{ lookup('community.hashi_vault.hashi_vault', 'ansible/data/example-job', auth_method='token') }}"
```

`VAULT_TOKEN` в окружении контейнера подхватывается из `.env.vault` run-скриптами.

## Troubleshooting

| Симптом | Действие |
|---------|----------|
| `permission denied` на `ansible/data/...` | Проверить policy token: `vault token lookup` |
| Пустой `.env.vault` после deploy | Проверить наличие `VAULT_ADDR` и `VAULT_TOKEN` в CI Variables |
| Web REPL: `Usage: vault <command>` | Использовать HTTP API или Vault CLI, не browser REPL |
| Run-скрипт не видит Vault | Запуск из `/ansible` под `ansible`; проверить `source .env.vault` |

См. также: `playbooks/vault-*.yml`, `roles/vault-*`, `group_vars/prod/vault_cluster.yml`, `scripts/prod/run-vault.sh`.

## GitLab Docker apps (cert-monitoring, cert-orchestrator, cloud-hibernate)

Секреты приложений в Vault KV `ansible/data/<env>/gitlab/<app>`. Доступ с контрол-ноды: `/ansible/.env.vault` (CI job `deploy-ansible:runner_host`).

- `docs/DOCKER_APPS.md`
- `docs/DOCKER_APPS_VAULT_SECRETS.md`
- `./scripts/run/run_docker_app.sh deploy cert-monitoring --prod --limit estate-prod-gitlab`
