# MCP tools catalog (sanitized)

Contracts used by a local SSE agent. Host names, tickets, and tokens stay in `chmod 600` env files, not here.

Fallback: if a named tool is missing, `run_script` or `host_exec` still covers the same `.sh` under allowed roots.

## Universal

| Tool | Job | Arguments |
|------|-----|-----------|
| `list_scripts` | Return the script catalog by category | none |
| `host_exec` | Run one bash command on the workstation | `command` |
| `run_script` | Run an allowed `.sh` | `path`, `args[]` |
| `mcp_health` | Probe SSE, env-file presence (keys only), SSH agent | none |

## SSH

| Tool | Job | Arguments |
|------|-----|-----------|
| `ssh_exec` | One remote command | `alias`, `command` |
| `ssh_run_script` | Copy a diagnostic script, run it, pull output | `alias`, `script`, `out` |
| `ssh_config` | Rewrite `~/.ssh/config` Include paths after a home move | none |
| `ssh_probe` | `BatchMode` probe of config aliases | `alias?` |
| `ssh_deploy_admin` | Install a named admin pubkey + NOPASSWD sudo (explicit) | `alias`, `pubkey` |
| `ssh_verify` | Login + `whoami` / `sudo -n true` | `alias` |
| `ssh_access_map` | Host / alias / user / key table from a TSV | `tsv?` |

Implementation: [`../scripts/utility/ssh/`](../scripts/utility/ssh/), [`../scripts/utility/mcp_ssh_env.sh`](../scripts/utility/mcp_ssh_env.sh).

## Kubernetes / GitOps

| Tool | Job | Arguments |
|------|-----|-----------|
| `kube_list_clusters` | Clusters under `~/.kube/clusters/*/config` + current | none |
| `kube_switch` | Point `~/.kube/config` at a named cluster | `name` |
| `kube_logs` | Dump pod logs to a file (no live grep of secrets) | `namespace`, `selector`, `since`, `out` |
| `argocd_sync_verify` | `app sync` + wait + optional rollout restart | `app[]`, `restart[]`, `namespace` |

Implementation: [`../scripts/k8s/`](../scripts/k8s/), [`../scripts/utility/k8s/argocd_deploy_verify.sh`](../scripts/utility/k8s/argocd_deploy_verify.sh).

## Ansible

| Tool | Job | Arguments |
|------|-----|-----------|
| `ansible_run` | `ansible-playbook` native or runner image | `--ansible-root`, `--inventory`, `--limit` or `--all`, `--playbook`, `--` extra |

Hard rules: `--limit` (or `--all`) is required; no TTY; log tee optional; secrets from env files, not argv.

Implementation: [`../scripts/utility/ansible/ansible_agent_run.sh`](../scripts/utility/ansible/ansible_agent_run.sh). Image: [`../../../../iac/ansible/reference/ansible-runner/`](../../../../iac/ansible/reference/ansible-runner/).

## Git hygiene

| Tool | Job | Arguments |
|------|-----|-----------|
| `git_list_dirty` | Porcelain status under a root | `--root` |
| `git_normalize_crlf` | Detect / strip CR so `bash\r` does not appear | `--root`, `--apply?` |
| `git_commit_push` | Stage + commit + push with a message (explicit) | `--root`, `--message` |

Implementation: [`../scripts/utility/git/`](../scripts/utility/git/).

## ITSM / wiki

| Tool | Job | Arguments |
|------|-----|-----------|
| `servicedesk_search` | Jira / JSM JQL search | `--project`, `--period`, `--jql` |
| `servicedesk_my_open` | Open issues for the token user | `--project?` |
| `servicedesk_issue` | Issue body, comments, attachments list | `key` |
| `servicedesk_comment` | POST a comment | `key`, `body` |
| `wiki_search` | Confluence-class CQL | `--space`, `--text`, `--cql` |

Implementation: [`../scripts/utility/servicedesk/`](../scripts/utility/servicedesk/), [`../scripts/utility/confluence/`](../scripts/utility/confluence/). Tokens: [`../secrets-env/`](../secrets-env/).

## Secrets (keys only)

| Tool | Job | Arguments |
|------|-----|-----------|
| `secrets_list` | Print key names and file size, never values | `alias?` |
| `secrets_verify` | `key=ok|empty` per file | `alias?` |
| `secrets_source_cmd` | Print `set -a; source PATH; set +a` | `alias` |

Implementation: [`../scripts/utility/list_secrets_env.sh`](../scripts/utility/list_secrets_env.sh).
