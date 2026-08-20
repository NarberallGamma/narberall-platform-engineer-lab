# mcp-agent

How the IDE talks to the workstation. Named MCP tools are shortcuts. The same agent still reaches any allowed script under [`../scripts/`](../scripts/).

## Three layers

| Layer | What it is | When it is enough |
|-------|------------|-------------------|
| Universal | `host_exec`, `run_script` | Any command or `.sh` under allowed roots |
| Catalog | `list_scripts` + [`script-catalog.json`](script-catalog.json) | Discover paths without walking the disk |
| Named wrappers | SSH, kube, Ansible, git, JSM, wiki | Frequent ops: schema, fewer quoting mistakes |

Named tools are desktop shortcuts. Universal tools are the full allowed filesystem. **Not every script needs its own tool.**

## Why named tools still exist

| Reason | Effect |
|--------|--------|
| Discoverability | The IDE lists tools; the agent picks a contract |
| Schema | `--limit`, `--ansible-root`, `--period` are arguments |
| Tokens | No need to recall the full path on every turn |
| Safety | Prod-shaped actions go through a wrapper |
| Speed | Fewer “guess the CLI” rounds |

## Files

| File | Job |
|------|-----|
| [`mcp.json`](mcp.json) | Local SSE ops agent + Replicate wrapper (no tokens) |
| [`tools-catalog.md`](tools-catalog.md) | Tool table and argument contracts |
| [`script-catalog.json`](script-catalog.json) | Category → script map |

On the workstation, Replicate `command` is `~/.local/bin/replicate-mcp-wrapper.sh`. The copy in `mcp.json` uses `/usr/local/bin/…` so a home path does not land in git.

Story: [`../../mcp-ops-toolchain.md`](../../mcp-ops-toolchain.md).
