# Utilities

CLIs and helpers that back the lab. Tokens and host paths stay out of git.

| Path | Purpose |
|------|---------|
| [`ansible-runner/`](ansible-runner/) | Alpine image: ansible-core + collections + jmespath |
| [`snap-pair/`](snap-pair/) | Paired btrfs snapshots + ESP rsync |
| [`mcp-replicate/`](mcp-replicate/) | MCP wrapper: credentials file → `npx replicate-mcp` |

Practice: [`../../practice/home-lab/os-workstation.md`](../../practice/home-lab/os-workstation.md), [`../../practice/workstation/mcp-ops-toolchain.md`](../../practice/workstation/mcp-ops-toolchain.md).
