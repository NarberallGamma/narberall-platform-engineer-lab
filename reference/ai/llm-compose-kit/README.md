# llm-compose-kit

Local LLM serving on a GPU workstation. 16 GB VRAM does not fit flagship 70B weights — this kit is sized for quantized 14B–32B class models.

Practice: [`../../../practice/home-lab/ai-lab.md`](../../../practice/home-lab/ai-lab.md). Cloud fallback: [`../../utilities/mcp-replicate/`](../../utilities/mcp-replicate/).

```bash
# GPU host with nvidia-container-toolkit
docker compose -f docker-compose.example.yml up -d
```

`OLLAMA_MODELS` and bind mounts stay local. No API keys in compose.

## Keywords

Ollama, Docker, CUDA, OpenAI-compatible API
