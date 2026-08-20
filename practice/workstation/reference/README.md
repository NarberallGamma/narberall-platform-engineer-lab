# Workstation kits (code next to the pages)

What actually ran on the workstation. Same files copy onto **Linux, macOS, or WSL** (bash + Docker + env files). Ansible runner image lives with Ansible: [`../../../iac/ansible/reference/ansible-runner/`](../../../iac/ansible/reference/ansible-runner/).

| Kit | What |
|-----|------|
| [`mcp-replicate/`](mcp-replicate/) | `replicate-mcp-wrapper.sh` + `replicate-img` (async poll, SOCKS CDN) |
| [`mcp-agent/`](mcp-agent/) | `mcp.json`, named-tool catalog, `script-catalog.json` |
| [`scripts/`](scripts/) | SSH, kube, Ansible, git hygiene, JSM, wiki, ACME, secrets list |
| [`secrets-env/`](secrets-env/) | Env-file layout (`chmod 600`, keys only) |

Index pages next to the scripts: [`ssh-ops/`](ssh-ops/), [`kube-ops/`](kube-ops/). Story: [`../mcp-ops-toolchain.md`](../mcp-ops-toolchain.md).
