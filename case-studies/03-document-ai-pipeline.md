# Case study: Document AI / OCR pipeline

**Context:** Enterprise capture (PDF / image → structured JSON → LLM extract → ERP-class handoff) next to a collab estate  
**Role:** Platform Engineer + integration owner

**Why business pays:** OCR plus LLM **multiplies** invoice, contract, and ticket loops. Accounting and analysts stop retyping PDFs. Not a chatbot slide. Manager page: [`../architecture/01-llmops.md`](../architecture/01-llmops.md). Buyer page: [`../docs/for-business.md`](../docs/for-business.md).

This is the **document path** next to [case 01](01-ai-llm-platform.md). Case 01 is the private GPU API and the collab inventory. This case is capture → extract → handoff. Honest scope: published results do not invent pages-per-hour or SLA.

## Challenge

PDFs and scans must become fields an ERP or 1C-class system can accept. The same company already runs ContentCapture-class OCR hosts, Nextcloud, n8n, and a private LLM API. Capture cannot be a laptop compose while the estate stays click-ops. Callers need a reverse-proxied service, a schema, and a failure path when OCR or extract is empty.

## Architecture

See diagram: [`diagrams/case-studies/03-document-ai-pipeline.md`](../diagrams/case-studies/03-document-ai-pipeline.md)

```text
1) Ingress: PDF / image into an OCR service (ContentCapture-class host on the collab inventory)
2) Extract: LLM over the private /v1 API from case 01 (no public-chat paste)
3) Schema: structured JSON the ERP / 1C edge can accept
4) Handoff: API or n8n webhook, not a shared folder drop
5) Host path: collab Compose snapshot for OCR next to the Ansible inventory that owns ACL
```

## What shipped

- Estate map: ContentCapture-class OCR hosts stay on the same inventory as Nextcloud, n8n, GitLab, and 1C ([`iac/ansible/reference/ansible-llm-collab/`](../iac/ansible/reference/ansible-llm-collab/))
- Host compose snapshot for the capture plane: [`iac/docker/compose/collab/`](../iac/docker/compose/collab/)
- Private LLM extract over the case 01 `/v1` path, not a public chat
- Sequence and vendor-handoff notes sanitized in this lab
- Workstation MCP stays a different story: [`practice/workstation/`](../practice/workstation/)

## Results

- Capture and extract are inventory and an API, not a one-off desktop install
- Tenant documents stay on the private path (OCR host + private LLM)
- Reviewers see the document loop next to case 01, not a second GPU demo
- No invented throughput numbers in this public slice

## Stack

OCR / ContentCapture-class, LLM extract, Docker Compose, nginx, Ansible inventory, n8n, ERP / 1C edge

## Links

- Sibling: [case 01](01-ai-llm-platform.md)
- Collab Ansible: [`iac/ansible/reference/ansible-llm-collab/`](../iac/ansible/reference/ansible-llm-collab/)
- Collab Compose: [`iac/docker/compose/collab/`](../iac/docker/compose/collab/)
- Manager LLMOps: [`architecture/01-llmops.md`](../architecture/01-llmops.md)
