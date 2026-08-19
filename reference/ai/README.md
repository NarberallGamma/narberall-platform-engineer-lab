# AI reference

Sanitized GPU compose and training presets. Narrative: [`../../practice/home-lab/ai-lab.md`](../../practice/home-lab/ai-lab.md).

**Business:** these kits are how a private API appears in **minutes** on a GPU box that already exists. Process speed (OCR, local chat, image jobs), not a slide. Manager page: [`../../architecture/01-llmops.md`](../../architecture/01-llmops.md). Kits below stay.

| Path | Purpose |
|------|---------|
| [`llm-compose-kit/`](llm-compose-kit/) | Ollama + optional WebUI, NVIDIA reservation |
| [`sd-compose/`](sd-compose/) | AUTOMATIC1111-class GPU compose (image not vendored) |
| [`kohya-lora-preset.example.md`](kohya-lora-preset.example.md) | LoRA knobs without dataset names |
| [`../utilities/mcp-replicate/`](../utilities/mcp-replicate/) | Replicate MCP wrapper (token stays in `~/.config`) |
