# mcp-replicate

The Replicate path used on the workstation: MCP for schema and create, CLI for upload / poll / CDN.

| File | Job |
|------|-----|
| [`replicate-mcp-wrapper.sh`](replicate-mcp-wrapper.sh) | Stdio MCP. Token from `~/.config/replicate/credentials.env` (`chmod 600`). Node does not speak `socks5h`; API stays direct. If `127.0.0.1:10808` is open, sets `REPLICATE_SOCKS` for the CLI only. |
| [`replicate-img`](replicate-img) | Python CLI: create with `wait=False`, poll ~2s, curl files API (SDK upload hangs), SOCKS CDN, jobs file, `--poll` after MCP create. |
| [`requirements.txt`](requirements.txt) | `replicate>=1.0.7` |

```bash
python3 -m venv ~/.local/share/replicate-cli/venv
~/.local/share/replicate-cli/venv/bin/pip install -r requirements.txt
install -m 755 replicate-img ~/.local/bin/replicate-img
# shebang in this tree is /usr/bin/env python3; on the workstation the file
# ran from the venv. Point PATH at the venv or keep env python3 + deps.

install -m 755 replicate-mcp-wrapper.sh ~/.local/bin/replicate-mcp-wrapper.sh
# ~/.config/replicate/credentials.env
# REPLICATE_API_TOKEN=r8_...
chmod 600 ~/.config/replicate/credentials.env
```

`mcp.json` command is the wrapper path. After MCP `create_models_predictions` (no `Prefer: wait`):

```bash
replicate-img --poll PREDICTION_ID --output-dir /tmp/out --name tag
```

Aliases in the CLI: `flux-kontext-pro`, `flux-2-pro`, `nano-banana-2`, `nano-banana-pro`, `gpt-image-2`.

Story: [`../../mcp-ops-toolchain.md`](../../mcp-ops-toolchain.md), [`../../../home-lab/ai-lab.md`](../../../home-lab/ai-lab.md). Agent map: [`../mcp-agent/`](../mcp-agent/).
