# Case study: AI / LLM inference platform

**Context:** Internal / enterprise AI next to a collab estate (GPU VM → OpenAI-compatible API; Nextcloud / n8n / Kafka on the same inventory)  
**Role:** Platform Engineer (Ansible owner for the GPU node and the collab estate)

**Why business pays:** a **private** OpenAI-compatible API so accounting, analysts, and developers stop pasting tenant data into a public chat. Throughput and ACL, not a demo chatbot. Manager page: [`../architecture/01-llmops.md`](../architecture/01-llmops.md). Buyer page: [`../docs/for-business.md`](../docs/for-business.md).

This is **proof** that LLM in this lab is coded Ansible, not a compose screenshot. The living tree is [`iac/ansible/reference/ansible-llm-collab/`](../iac/ansible/reference/ansible-llm-collab/). Home-lab GPU compose (Ollama / SD / Kohya) is a different path: [`../practice/home-lab/ai-lab.md`](../practice/home-lab/ai-lab.md).

Not a Huawei docker_app estate. That proof is [case 10](10-ansible-estate.md). Not payments identity. That proof is [case 08](08-payments-swarm-autodeploy.md).

## Challenge

A GPU VM is not enough. Callers need HTTPS `/v1`, a WebUI, and a chat-template that does not 400 when a desktop client omits `role=system`. The same company still runs Nextcloud (dev + prod HA + regul), n8n, Kafka, JSM, GitLab, 1C, and ContentCapture-class OCR. Those hosts must stay inventory: AD/SSSD, Docker CE, optional NVIDIA, CIS Ubuntu 24, EDR. Folder ACL per client must be a playbook (and an n8n form), not a ticket.

Honest scope: published results do not invent tokens/s or SLA. Capacity knobs (16 GiB VRAM, Qwen GGUF Q4, context ladder) live in `group_vars/llm_dev/`.

## Architecture

See diagram: [`diagrams/case-studies/01-ai-llm-platform.md`](../diagrams/case-studies/01-ai-llm-platform.md)

```text
1) inventories/hosts.ini.example: llm_dev + Nextcloud + Kafka + 1C/OCR + GitLab/JSM + PG/Redis + prepare
2) prepare_servers / CIS on the prepare group
3) llm_dev: GGUF fetch → llama.cpp CUDA → Open WebUI → nginx TLS /v1 (Ouroboros template patch)
4) nextcloud_groupfolders: matrix + WebDAV MKCOL + occ ACL
5) n8n_workflows: form + webhook GitOps back to the Ansible control node
6) kafka_deploy + extras/sec-stack metrics
7) scripts/db_migration/ when 1C-class PostgreSQL moves host
```

## What shipped

- Private GPU API: llama.cpp CUDA server, Open WebUI, nginx TLS, `/v1` rewrite
- Model path as code: Hugging Face GGUF catalog, manifest, Vault key names only
- Client compatibility: patched Qwen chat template for Ouroboros-class callers
- Collab Ansible: Nextcloud groupfolders matrices, n8n form/webhook sync
- Estate map kept whole (GitLab, JSM, 1C, ContentCapture-class, Patroni-class PG, Redis, Teleport)
- Host harden: CIS Ubuntu 24 + prepare (Docker, NVIDIA CDI, EDR toggles)
- Public lab: brands and live secrets stripped; role logic kept

## Results

- **1–2 weeks** to a usable private `/v1` API once the GPU host and inventory exist (package calendar)
- **Hours for the next client folder:** `--limit` + n8n/playbook ACL, not a per-tenant SSH week
- **Ship:** accounting and analysts stop pasting tenant data into a public chat. Collab plane stays on the same inventory
- Home-lab compose is the workstation story. This tree is the estate story

## Stack

Linux, Docker, nginx, llama.cpp / NVIDIA, Ansible, Vault, Nextcloud, n8n, Kafka, CIS Ubuntu 24, PostgreSQL, Redis

## Links

- Sanitized Ansible tree: [`iac/ansible/reference/ansible-llm-collab/`](../iac/ansible/reference/ansible-llm-collab/)
- Ansible hub: [`iac/ansible/`](../iac/ansible/)
- Home lab GPU / SD / MCP: [`practice/home-lab/ai-lab.md`](../practice/home-lab/ai-lab.md)
- Reference compose: [`practice/home-lab/reference/ai/llm-compose-kit/`](../practice/home-lab/reference/ai/llm-compose-kit/)
- Workstation MCP + CLI: [`practice/workstation/reference/mcp-replicate/`](../practice/workstation/reference/mcp-replicate/)
