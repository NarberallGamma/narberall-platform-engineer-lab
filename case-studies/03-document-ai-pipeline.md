# Case study: Document AI / OCR pipeline

**Status:** stub  
**Context:** Enterprise document processing (OCR → structured JSON → LLM)  
**Role:** Platform Engineer + integration owner

**Why business pays:** OCR + LLM **multiplies** invoice, contract, and ticket loops. Accounting and analysts stop retyping PDFs. Not a chatbot slide. Manager page: [`../architecture/01-llmops.md`](../architecture/01-llmops.md). Existing stub sections stay.

## Challenge

Reliable PDF/image capture to structured fields with API handoff to ERP-class systems.

## Architecture

See diagram: [`diagrams/case-studies/03-document-ai-pipeline.md`](../diagrams/case-studies/03-document-ai-pipeline.md)

## What shipped

- Infra: Dockerized OCR/LLM services, reverse proxy
- App/utilities: extraction schemas, API POC tooling
- Docs: sequence diagrams, vendor handoff notes (sanitized)
- Monitoring: pipeline health / failure visibility (as applicable)

## Results

_(fill)_

## Stack

OCR engine, LLM extraction, Docker, API gateway patterns, ERP integration edge

## Links

- Related practice: workstation MCP tooling in [`practice/workstation/`](../practice/workstation/) (not this case)
