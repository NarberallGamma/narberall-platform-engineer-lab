# MCP ops toolchain

**Role:** I treat the IDE as part of the platform: MCP servers, wrapper scripts, rules, and ignore files are the "bootstrap playbook" for a workstation (WSL first, then native Linux).

## What I automate

| Layer | What |
|-------|------|
| MCP | Servers declared in `mcp.json`; wrappers so tokens stay in `chmod 600` env files, not in git or chat |
| CLI helpers | Thin Python/bash around HTTP APIs (example: Replicate create + poll + CDN download, no sync-wait on cold GPUs) |
| Rules | Persistent editor/workspace rules: git layout, Linux vs WSL, Docker socket, snap-pair before boot/kernel, public-repo sanitize |
| Index | `.cursorignore` + editor excludes so the IDE does not index Steam, backups, or `/` (Extension Host crash / 30s scans) |
| Shell | Native bash; Docker via the host socket; SSH aliases + keys; Ansible only through the runner image |
| Line endings | LF-only for playbooks and `*.sh` (WSL/Windows dual-boot used to inject `bash\r`) |

## WSL → native Linux

Same mental model on both:

1. **WSL2** (Windows era): Docker Desktop, GPU in the VM, git on a data disk, ansible-runner image, SD WebUI compose
2. **Native Arch**: docker group, compose plugin, same runner image, same playbooks, CUDA from distro packages

The substrate is explicit in those rules (no "assume WSL" after migration). Sandbox vs real `/var/run/docker.sock` is a documented failure mode, not a permissions cargo-cult.

## Why it matters for hiring (2026)

Leads do not need another "I use ChatGPT". They need someone who can **wire tools**: MCP, secrets on disk, async APIs, GPU cold start, CDN vs API routes, ignore files, and a workstation that MCP/CLI tools can use without indexing the world.

Proof of the same pattern on the server side: [`../home-lab/edge-platform.md`](../home-lab/edge-platform.md) (Ansible runner + artifacts). Proof on the model side: [`../home-lab/ai-lab.md`](../home-lab/ai-lab.md) (Replicate MCP + local CUDA).

Code: [`../../reference/utilities/ansible-runner/`](../../reference/utilities/ansible-runner/), [`../../reference/utilities/mcp-replicate/`](../../reference/utilities/mcp-replicate/).

## Stack

Linux, bash, Docker, SSH, Ansible runner, MCP, Python venv CLIs, kubectl when a cluster is in scope, git

## Keywords

MCP, Cursor, WSL, Docker, Ansible, SSH, GitOps, workstation automation, secrets management
