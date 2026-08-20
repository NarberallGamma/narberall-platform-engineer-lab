# terraform-ai-stack

**Map, not a rewrite.** This folder is the IaC pointer for LLMOps. Published GPU/LLM proof already lives elsewhere and stays there. Nothing here replaces compose kits, cases 01/03, or AWS live.

**Business:** OCR/LLM exists to **speed accounting, analysts, and developers**. Local or private API so tenant data does not go into a public chat. Manager page: [`../../../architecture/01-llmops.md`](../../../architecture/01-llmops.md).

| Existing proof | What it is |
|----------------|------------|
| [`../../../practice/home-lab/reference/ai/llm-compose-kit/`](../../../practice/home-lab/reference/ai/llm-compose-kit/) | Ollama-class GPU serve (Compose) |
| [`../../../practice/home-lab/ai-lab.md`](../../../practice/home-lab/ai-lab.md) | Workstation / lab GPU story |
| [`../../../case-studies/01-ai-llm-platform.md`](../../../case-studies/01-ai-llm-platform.md) | Inference platform case |
| [`../../../case-studies/03-document-ai-pipeline.md`](../../../case-studies/03-document-ai-pipeline.md) | OCR → JSON → LLM |
| [`../aws/live/`](../aws/live/) | EKS + Karpenter-class GPU scale placeholder |
| [`../modules/`](../modules/) | Huawei-class VPC/compute if the GPU box sits on cloud.ru |

A future compose of modules + GPU extras can land **in this folder** without moving the trees above. Vector store (Qdrant-class / Pinecone-class) and vLLM-class serve are **patterns**, not invented production trees in this lab.

General platform IaC: [`../README.md`](../README.md) and [`../../cloud/`](../../cloud/).
