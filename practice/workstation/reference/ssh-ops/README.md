# ssh-ops

Scripts: [`../scripts/utility/mcp_ssh_env.sh`](../scripts/utility/mcp_ssh_env.sh), [`../scripts/utility/ssh/`](../scripts/utility/ssh/), [`../scripts/utility/fix-ssh-config-paths.sh`](../scripts/utility/fix-ssh-config-paths.sh).

| Script | Job |
|--------|-----|
| `mcp_ssh_env.sh` | Pick an agent with keys, resolve alias via `ssh -G`, set `SSH_OPTS` |
| `ssh_probe_aliases.sh` | BatchMode TSV: alias, IP, user, OK/FAIL |
| `ssh_verify_aliases.sh` | `hostname -s` per alias |
| `ssh_deploy_admin.sh` | Pubkey + NOPASSWD sudo for `TARGET_USER` (default `admin`) |
| `fix-ssh-config-paths.sh` | Windows ↔ Linux IdentityFile, Host fragments, add/remove Host |

Default identity is `~/.ssh/id_ed25519` (`SSH_UTIL_KEY`). MCP tools: `ssh_exec`, `ssh_probe`, `ssh_verify`, `ssh_deploy_admin` in [`../mcp-agent/tools-catalog.md`](../mcp-agent/tools-catalog.md).
