# secrets-env

Env files on disk, `chmod 600`, never in git. The inventory script only prints **key names** and `ok|empty`. High-value production secrets stay in Vault / SOPS / Ansible Vault; this kit is the workstation layer. Policy: [`../../../../docs/security-ai.md`](../../../../docs/security-ai.md).

| File | Job |
|------|-----|
| [`../scripts/utility/list_secrets_env.sh`](../scripts/utility/list_secrets_env.sh) | `list` / `paths` / `verify` / `source-cmd` / `with-env` |
| [`env.example`](env.example) | Placeholder keys for JSM, wiki, Replicate, registry |

```bash
# ~/.config/ops/.env-lab
chmod 600 ~/.config/ops/.env-*
../scripts/utility/list_secrets_env.sh list lab
../scripts/utility/list_secrets_env.sh verify lab
../scripts/utility/list_secrets_env.sh with-env lab -- ../scripts/utility/servicedesk/sd_search.sh --project OPS --period 7d
```

Aliases: `lab`, `estate`/`cr`, `edge`, `cloud`, `vault`. MCP tools: `secrets_list`, `secrets_verify` in [`../mcp-agent/tools-catalog.md`](../mcp-agent/tools-catalog.md).
