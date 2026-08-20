# scripts

The workstation ops tree. Same layout as on the box (`~/scripts` plus `k8s/`). MCP named tools call these files; `run_script` / `host_exec` cover the rest.

Tokens stay in `chmod 600` files under `~/.config/ops/` and `~/.config/replicate/`. No live URLs or keys in this tree.

```text
scripts/
  k8s/                         kube-switch, kube-logs
  utility/
    mcp_ssh_env.sh             SSH_AUTH_SOCK + ssh -G
    fix-ssh-config-paths.sh    Windows/WSL SSH config, IdentityFile, Host blocks
    list_secrets_env.sh        key names only
    cursorindexingignore.common
    lib/infra_paths.sh         OPS_ROOT / GIT_ENV_ROOT
    ssh/                       probe, verify, deploy admin pubkey
    ansible/ansible_agent_run.sh
    git/                       dirty list, CRLF phantom, commit/push, HTTPS PAT
    k8s/argocd_deploy_verify.sh
    servicedesk/               JSM search / issue / comment / create
    confluence/                CQL + page CRUD
    certs/check_acme_txt.sh    DNS-01 before certbot Enter
```

## SSH

```bash
source utility/mcp_ssh_env.sh jump
utility/ssh/tools/ssh_probe_aliases.sh jump
utility/ssh/tools/ssh_verify_aliases.sh jump
# TARGET_USER=admin utility/ssh/tools/ssh_deploy_admin.sh jump
```

`fix-ssh-config-paths.sh` is the long WSL-era helper: fix IdentityFile paths, add Host fragments, sync Windows `~/.ssh/config` into Linux.

## Kubernetes

```bash
k8s/kube-switch.sh list
k8s/kube-switch.sh preprod
k8s/kube-logs.sh -n app
utility/k8s/argocd_deploy_verify.sh --cluster preprod --app api --restart deploy/api
```

`kube-switch` keeps `~/.kube/clusters/<name>/config` and points `~/.kube/config` at the active one. `kube-logs` writes a file (interactive namespace / workload / window).

## Ansible

```bash
utility/ansible/ansible_agent_run.sh \
  --ansible-root /path/to/ansible \
  --inventory inventories/prod/hosts.ini \
  --limit app-1 \
  --playbook playbooks/prepare_servers.yml \
  --ssh-agent --out /tmp/ansible.log
```

`--limit` or `--all` is required. Native `ansible-playbook` by default; `--docker` uses `ANSIBLE_IMAGE` (lab image: [`../../../../iac/ansible/reference/ansible-runner/`](../../../../iac/ansible/reference/ansible-runner/)). Copy of the tree goes to `/tmp/ansible-agent-$$` so the agent does not write the git worktree.

## Git

```bash
utility/git/tools/list_dirty_repos.sh --env PREPROD
utility/git/tools/normalize_worktree_before_dirty_check.sh --env ALL
utility/git/git_commit_push.sh --env PREPROD --message "…" --all-changed
```

CRLF phantom: restore to HEAD, do not blind-strip. HTTPS push uses GIT_ASKPASS + PAT from `~/.config/ops/.env-cloud` (`GITLAB_TOKEN_PROD` / `GITLAB_TOKEN_PREPROD`). Hosts come from `GITLAB_HOST_PROD` / `GITLAB_HOST_PREPROD`.

## JSM / wiki

```bash
utility/list_secrets_env.sh verify lab
utility/servicedesk/sd_search.sh --project OPS --period 7d
utility/confluence/cf_search.sh --space OPS --text 'runbook'
```

Base URLs are required in the env file (`SERVICEDESK_BASE_URL`, `CONFLUENCE_BASE_URL`).

## ACME

```bash
utility/certs/check_acme_txt.sh --name _acme-challenge.example.invalid --value VAL
```

Exit 0 only when selected NS (and public resolvers) return every value.

MCP contracts: [`../mcp-agent/`](../mcp-agent/). Replicate CLI: [`../mcp-replicate/`](../mcp-replicate/).
