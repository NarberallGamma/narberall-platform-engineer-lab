# Diagram: AI / LLM inference platform

```mermaid
flowchart LR
  GPU[GPU VM]
  GPU --> Serve[llama.cpp / Ollama class]
  Serve --> API[OpenAI-compatible HTTP]
  API --> Edge[TLS reverse proxy]
  Edge --> Clients[curl / WebUI / apps]
  Ans[Ansible + Compose] --> GPU
```

Case study: [`../../case-studies/01-ai-llm-platform.md`](../../case-studies/01-ai-llm-platform.md).  
Code: [`../../practice/home-lab/reference/ai/llm-compose-kit/`](../../practice/home-lab/reference/ai/llm-compose-kit/), [`../../practice/home-lab/ai-lab.md`](../../practice/home-lab/ai-lab.md).
