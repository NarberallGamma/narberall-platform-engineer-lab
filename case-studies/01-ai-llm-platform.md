# Case study: AI / LLM inference platform

**Status:** stub (Work PC fills from career notes)  
**Context:** Internal / enterprise AI platform (GPU VM → OpenAI-compatible API)  
**Role:** Platform Engineer (sole owner)

## Challenge

Stand up production-usable LLM inference with HTTPS API, ops automation, and capacity tuning.

## Architecture

_(diagram TBD → `diagrams/case-studies/01-ai-llm-platform`)_

## What shipped

- Infra: VM/GPU path, reverse proxy, TLS, Ansible deploy
- App: OpenAI-compatible API, WebUI, client integrations
- Docs: handoff for testers (curl / OpenAI spec)
- Monitoring: capacity / VRAM / context limits (document in results)

## Results

_(fill: context window, migration, uptime/ops outcome)_

## Stack

Linux, Docker, nginx, llama.cpp / GPU, Ansible, optional RAG edge

## Links

- Reference: `../reference/ai/llm-compose-kit/`
