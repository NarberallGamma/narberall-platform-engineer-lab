# Vault: ansible integration (PROD)

Control node: directory **`/ansible`** on **estate-prod-gitlab** after deploy from Git (`main` branch).

| Parameter | PROD value |
|----------|---------------|
| Vault URL | `https://vault.example.com` |
| KV engines | `ansible/` (cert-*, cloud-hibernate), `secret/` (hsm-adapter and others) |
| Policy for the CI token | `ansible-control` |
| GitLab project | `platform/ansible` on prod GitLab |
| CI Variables | `VAULT_ADDR`, `VAULT_TOKEN` |

## How it works

1. GitLab CI of the **ansible** project has `VAULT_ADDR` and `VAULT_TOKEN`.
2. Pipeline `deploy-ansible:runner_host` (`common-ci/deploys/ansible-deploy.yaml`) on push to `main` writes **`/ansible/.env.vault`** (chmod 600, owner `ansible`).
3. Run scripts (`scripts/run/*.sh`) via `scripts/run/lib/control_node_env.sh` run `source .env.vault` and pass `VAULT_*` into the Ansible container.

File `.env.vault` is not stored in git (see `.gitignore`).

## Policy `ansible-control`

The CI token reads secrets from two KV v2 mounts:

| Mount | Example paths | Purpose |
|-------|--------------|--------|
| **`ansible/`** | `cert-monitoring`, `cert-orchestrator`, `cloud-hibernate-operator` | docker_app under `/docker/apps` |
| **`secret/`** | `treasury-hsm-adapter`, `treasury-*-app` | hsm-adapter and legacy treasury secrets |

Canonical HCL: **`docs/policies/ansible-control.hcl`**.

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

Create/update via UI: **Policies** → `ansible-control` → Edit ACL Policy.  
CLI (root/admin on the **active** node or via API without redirect to `127.0.0.1`):

```bash
export VAULT_ADDR=http://127.0.0.1:8200   # on the vault node
export VAULT_TOKEN=<root>
vault policy write ansible-control docs/policies/ansible-control.hcl
```

Policy changes apply to already-issued tokens immediately (reissue is not required).

## Issue a token for GitLab CI

**Web REPL in the Vault UI** (`read`, `kv-get`, …) **does not support** `vault token create`. Use the HTTP API or Vault CLI.

### Method 1: HTTP API (recommended)

Admin token: UI → user icon → Copy token, or root from init.

```bash
export VAULT_ADDR=https://vault.example.com
export VAULT_TOKEN=<admin-token>

curl -sS \
  --header "X-Vault-Token: ${VAULT_TOKEN}" \
  --request POST \
  --data '{"policies":["ansible-control"],"period":"768h","display_name":"ansible-gitlab-control-prod","no_default_policy":true}' \
  "${VAULT_ADDR}/v1/auth/token/create" | jq -r '.auth.client_token'
```

Output `hvs....` → GitLab **Settings → CI/CD → Variables** → `VAULT_TOKEN` (Mask, Protected).

### Method 2: Vault CLI

```bash
export VAULT_ADDR=https://vault.example.com
export VAULT_TOKEN=<admin-token>

vault token create \
  -policy=ansible-control \
  -period=768h \
  -display-name="ansible-gitlab-control-prod" \
  -no-default-policy
```

## Fast rotation of `VAULT_TOKEN` in estate PROD

1. Issue a new token (HTTP API or CLI above). Period `768h` = 32 days; increase `period` in JSON if needed.
2. GitLab prod → project **ansible** → **Settings → CI/CD → Variables** → **`VAULT_TOKEN`** → Edit → paste the new `hvs....` → Save.
3. Start the pipeline: push to `main` or **Run pipeline** on branch `main` (job `deploy-ansible:runner_host`).
4. On **estate-prod-gitlab** check:
   ```bash
   sudo ls -la /ansible/.env.vault
   sudo -u ansible grep VAULT_ADDR /ansible/.env.vault
   ```
5. Check access with the new token:
   ```bash
   export VAULT_ADDR=https://vault.example.com
   export VAULT_TOKEN=<new-token>
   vault kv list ansible/
   ```
6. Revoke the old token (optional, after the check):
   ```bash
   vault token revoke <old-hvs...>
   ```

A simple push with no code changes also rewrites `.env.vault` if the GitLab variable is already updated.

## GitLab CI Variables (PROD ansible)

| Variable | Mask | Protected | Example |
|----------|------|-----------|--------|
| `VAULT_ADDR` | no | yes | `https://vault.example.com` |
| `VAULT_TOKEN` | yes | yes | `hvs....` (token with policy `ansible-control`) |

Preprod: a separate token and `https://vault.preprod.example.com` in preprod GitLab.

## Secrets in engine `ansible/`

```bash
vault kv put ansible/example-job db_password="..." api_key="..."
vault kv get ansible/example-job
```

In the playbook (lookup):

```yaml
- debug:
    msg: "{{ lookup('community.hashi_vault.hashi_vault', 'ansible/data/example-job', auth_method='token') }}"
```

`VAULT_TOKEN` in the container environment is picked up from `.env.vault` by the run scripts.

## Troubleshooting

| Symptom | Action |
|---------|----------|
| `permission denied` on `ansible/data/...` | Check the token policy: `vault token lookup` |
| Empty `.env.vault` after deploy | Check that `VAULT_ADDR` and `VAULT_TOKEN` exist in CI Variables |
| Web REPL: `Usage: vault <command>` | Use the HTTP API or Vault CLI, not the browser REPL |
| Run script does not see Vault | Run from `/ansible` as `ansible`; check `source .env.vault` |

See also: `playbooks/vault-*.yml`, `roles/vault-*`, `group_vars/prod/vault_cluster.yml`, `scripts/prod/run-vault.sh`.

## GitLab Docker apps (cert-monitoring, cert-orchestrator, cloud-hibernate)

Application secrets in Vault KV `ansible/data/<env>/gitlab/<app>`. Access from the control node: `/ansible/.env.vault` (CI job `deploy-ansible:runner_host`).

- `docs/DOCKER_APPS.md`
- `docs/DOCKER_APPS_VAULT_SECRETS.md`
- `./scripts/run/run_docker_app.sh deploy cert-monitoring --prod --limit estate-prod-gitlab`
