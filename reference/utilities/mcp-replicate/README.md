# mcp-replicate

Wrapper so the Replicate MCP server reads the token from a **chmod 600** env file, not from git or chat.

```bash
# ~/.config/replicate/credentials.env  (not in this repo)
# REPLICATE_API_TOKEN=r8_...
./replicate-mcp-wrapper.example.sh
```

Production flow is **async poll** (no `Prefer: wait` on pro models; GPU cold start 2–3 min). CDN download is a separate network path from `api.replicate.com`.

Practice: [`../../../practice/home-lab/ai-lab.md`](../../../practice/home-lab/ai-lab.md), [`../../../practice/workstation/mcp-ops-toolchain.md`](../../../practice/workstation/mcp-ops-toolchain.md).
