# Workstation ops

**Business:** the IDE is a share of the platform, not a personal preference. MCP, wrappers, and scripts cut the same calendar as the cloud offer: IaC, Ansible, tickets, GPU jobs. I run that loop as a **multi-agent desk** (Cursor, Claude Code, Codex, local LLM plus VS Code-class wrappers), not one chat window. Local model when VRAM fits; API when it does not. Tenant data stays off a public chat. Manager page: [`../../architecture/01-llmops.md`](../../architecture/01-llmops.md). Product APIs: [`../../architecture/06-product-apis.md`](../../architecture/06-product-apis.md). Secrets and cybersec trust: [`../../docs/security-ai.md`](../../docs/security-ai.md).

How I stand up that loop so it is **repeatable on a new machine in hours**. The contract is bash, Docker, env files, and `mcp.json` — **Linux, macOS, or WSL**. WSL2 was the Windows-era host; native Linux is the current one. Neither is the product.

Public text stays high-level. No internal URLs, tokens, or host paths.

| Page | Topic |
|------|--------|
| [`mcp-ops-toolchain.md`](mcp-ops-toolchain.md) | MCP servers, named tools, Replicate CLI, ignore files, any-OS bootstrap, multi-agent hosts (Cursor / Claude / Codex / local), estate product APIs (Grafana, Vault, Argo, JSM) |

Code: [`reference/`](reference/) (`mcp-replicate/`, `mcp-agent/`, `scripts/`). Ansible image: [`../../iac/ansible/reference/ansible-runner/`](../../iac/ansible/reference/ansible-runner/).  
Home lab GPU compose: [`../home-lab/`](../home-lab/).
