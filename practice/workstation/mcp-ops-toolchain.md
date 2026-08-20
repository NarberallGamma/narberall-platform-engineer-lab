# MCP ops toolchain

**Role:** I treat the IDE as part of the platform: MCP servers, wrapper scripts, rules, and ignore files are the bootstrap playbook for a workstation. Same share of the offer as Ansible on a host: hours to a usable loop, not a week of click-ops.

## What I automate

| Layer | What |
|-------|------|
| MCP | [`reference/mcp-agent/mcp.json`](reference/mcp-agent/mcp.json): SSE ops agent + Replicate wrapper. Tokens in `chmod 600` env files, not in git |
| Named tools | SSH, kube, Argo CD, Ansible, git hygiene, JSM, wiki — catalog in [`reference/mcp-agent/tools-catalog.md`](reference/mcp-agent/tools-catalog.md) |
| Scripts | The same files the tools call: [`reference/scripts/`](reference/scripts/) |
| Replicate | [`reference/mcp-replicate/`](reference/mcp-replicate/): wrapper + `replicate-img` (create `wait=False`, poll, SOCKS CDN) |
| Local models | Ollama / llama.cpp-class when VRAM fits; compose kits under [`../home-lab/reference/ai/`](../home-lab/reference/ai/) |
| Index | [`reference/scripts/utility/cursorindexingignore.common`](reference/scripts/utility/cursorindexingignore.common) so the IDE does not index Steam, backups, or binary dumps |
| Shell | Native bash; Docker via the host socket; SSH aliases; Ansible through `ansible_agent_run.sh` (native or runner image) |
| Line endings | LF-only for playbooks and `*.sh`. CRLF phantom: restore to HEAD, do not blind-strip |

Named tools are shortcuts. `run_script` / `host_exec` still reach any allowed `.sh`. Not every script needs its own tool.

## Any OS (not a Windows/WSL lock-in)

The portable surface is **bash + Docker + env files + `mcp.json`**. Copy the wrappers, point tokens at `chmod 600` files, restart the IDE MCP.

| Host | What changes | What stays |
|------|----------------|------------|
| Native Linux | docker group, distro CUDA if a GPU is local | Same runner image, playbooks, MCP command |
| macOS | Docker Desktop or Colima; no WSL path rewrite | Same scripts, same `mcp.json` shape |
| WSL2 | Docker Desktop / socket; `fix-ssh-config-paths.sh` if keys lived on the Windows side | Same wrappers once `~/.ssh` and env files exist |

WSL was the **first** substrate, then native Arch. The kit is written so the next laptop is a copy, not a rewrite. Sandbox vs real `/var/run/docker.sock` is a documented failure mode, not a permissions cargo-cult.

## Why it matters for hiring (2026)

Leads do not need another "I use ChatGPT". They need someone who can **wire tools**: MCP, secrets on disk, async APIs, GPU cold start, CDN vs API routes, ignore files, and a workstation that MCP/CLI tools can use without indexing the world — on whatever OS the team already has.

Proof of the same pattern on the server side: [`../home-lab/edge-platform.md`](../home-lab/edge-platform.md) (Ansible runner + artifacts). Proof on the model side: [`../home-lab/ai-lab.md`](../home-lab/ai-lab.md) (Replicate MCP + local CUDA).

## Stack

Linux or macOS, bash, Docker, SSH, Ansible runner, MCP, Python venv CLIs, kubectl, Argo CD CLI, git, Jira/JSM REST, Confluence REST

## Keywords

MCP, local LLM, Replicate, Docker, Ansible, SSH, GitOps, workstation automation, secrets management, Argo CD, JSM, WSL, Linux, macOS
