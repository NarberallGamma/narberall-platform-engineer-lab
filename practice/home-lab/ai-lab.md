# Local AI lab

**Business:** a private GPU API so document and analysis work stays off public chats. Hardware list below is unchanged. Manager page: [`../../architecture/01-llmops.md`](../../architecture/01-llmops.md).

**Role:** GPU workstation for inference, LoRA training, and API-backed generation. Local when it fits VRAM; MCP/API when the model does not.

## Hardware (generic)

RTX 4080 **16 GB**, Ryzen 9 9950X3D, 64 GB RAM. That bounds what runs locally vs what goes to an API.

## CUDA baseline

- `nvidia-open` + CUDA 13 + `nvcc` + `nvidia-smi` / `nvtop`
- Docker with GPU (first on **WSL2**: 32 GB RAM / 6 cores assigned to the VM; then **native Arch**)
- Same compose/image workflow on both substrates so the lab survived the OS migration

## Image generation (Stable Diffusion)

| Piece | What I run |
|-------|------------|
| UI | AUTOMATIC1111 in Docker, GPU passthrough |
| Bases | SDXL (Juggernaut / Pony / `sd_xl_base`) plus SD1.5 checkpoints |
| Swap | ~1–2 min to switch SDXL weights in VRAM |
| Training | Kohya_ss: LoRA on SD1.5/SDXL, AdamW8bit, cosine LR, buckets, captions |
| Data | Small character/style sets (tens of images), epoch-based runs, fp16 |

This is ML **ops**, not research science: datasets on disk, compose, presets, VRAM-aware batch size, artifacts as `.safetensors`.

## Local LLM

16 GB VRAM does **not** fit flagship 70B/full GLM-class weights. Practical local set:

| Use | Class that fits |
|-----|-----------------|
| Coding / DevOps chat | Qwen2.5-Coder ~14B or similar quantized |
| General / RP | 14B–32B quantized with offload where needed |
| Serving | Ollama / llama.cpp-class; OpenAI-compatible HTTP when I expose an API |

Sizing is treated as capacity planning (context, VRAM, offload), the same as picking node types in a cluster. OS-side knobs (cgroups, swap, affinity, driver) live on [os-workstation.md](os-workstation.md) — the GPU stack is not a black box on a generic desktop install.

## Cloud models via MCP (Replicate)

When local VRAM is the bottleneck I drive **Replicate** as an HTTP platform:

- MCP server in the IDE (search models, create predictions, upload references, poll)
- CLI helper: create → poll (no `Prefer: wait` on pro models; cold start 2–3 min)
- Aliases: FLUX, Kontext, Nano Banana, GPT-image class
- Outputs + `*-meta.json` (prediction id, prompt, paths)
- Token in `chmod 600` env file, never in git

Async poll is the production pattern (connect timeouts vs GPU cold start). CDN download is a separate network path from the API host (see [networking.md](networking.md)).

## Proof of code

| Kit | Path |
|-----|------|
| Ollama compose | [`../../reference/ai/llm-compose-kit/`](../../reference/ai/llm-compose-kit/) |
| SD GPU compose | [`../../reference/ai/sd-compose/`](../../reference/ai/sd-compose/) |
| Kohya LoRA preset | [`../../reference/ai/kohya-lora-preset.example.md`](../../reference/ai/kohya-lora-preset.example.md) |
| Replicate MCP wrapper | [`../../reference/utilities/mcp-replicate/`](../../reference/utilities/mcp-replicate/) |

## Diagram

See [`../../diagrams/practice/home-lab/ai-lab.md`](../../diagrams/practice/home-lab/ai-lab.md).

## Keywords

CUDA, NVIDIA, LLM, Ollama, llama.cpp, Stable Diffusion, SDXL, LoRA, Kohya, Docker, MCP, Replicate, WSL, Arch Linux
