# Diagram: AI / LLM inference platform

```mermaid
flowchart TB
  subgraph callers [Callers]
    Acc[Accounting / analysts]
    Dev[Developers / on-call]
    UI[Open WebUI]
  end
  subgraph gpu [GPU node]
    Fetch[GGUF fetch]
    Serve[llama.cpp CUDA]
    Tpl[Ouroboros chat template]
    Nginx[nginx TLS /v1]
  end
  subgraph collab [Same inventory]
    NC[Nextcloud groupfolders]
    N8n[n8n form + webhook]
    Kfk[Kafka KRaft]
    CIS[CIS + prepare_servers]
  end
  Acc --> Nginx
  Dev --> Nginx
  UI --> Serve
  Fetch --> Serve
  Tpl --> Serve
  Serve --> Nginx
  N8n --> NC
  CIS --> gpu
  CIS --> collab
  Ans[Ansible llm-collab] --> gpu
  Ans --> collab
```

Case study: [`../../case-studies/01-ai-llm-platform.md`](../../case-studies/01-ai-llm-platform.md).  
Code: [`../../iac/ansible/reference/ansible-llm-collab/`](../../iac/ansible/reference/ansible-llm-collab/).  
Home-lab compose (separate path): [`../../practice/home-lab/ai-lab.md`](../../practice/home-lab/ai-lab.md).
