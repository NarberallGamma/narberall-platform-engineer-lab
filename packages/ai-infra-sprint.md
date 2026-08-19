# AI Infra Sprint

**Duration:** 1–2 weeks (typical)

**Business:** private LLM/OCR so finance, analysts, and developers finish document loops faster. Not a chatbot demo. [`../architecture/01-llmops.md`](../architecture/01-llmops.md).

## Deliverables

- Deploy LLM or RAG-oriented stack (API, storage, basic auth at edge)
- Monitoring and backup baseline
- Short runbook (deploy, upgrade, restore)
- Secrets and access as part of the sprint (no long-lived keys in git; Vault / ESO / protected CI when the stack needs them)

Fits a new stack or an existing GPU/VM that needs to become an operable API quickly.

## Out of scope (default)

- Model training / research science
- Unlimited custom product features

## Proof in this repo

- Case study: `case-studies/01-ai-llm-platform.md`
- Code: `reference/ai/llm-compose-kit/`
