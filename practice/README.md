# Practice (Lab & tooling)

**Business first:** local LLM and workstation MCP exist to **shorten real work** — the same calendar as Terraform and Ansible, not a side hobby. Accounting and analysts get a private API. Developers and on-call stop pasting tenant data into a public chat. The IDE runs SSH, kube, playbooks, and GPU jobs the way a control node would. Buyer page: [`../docs/for-business.md`](../docs/for-business.md).

Not client case studies. Same ownership pattern as production: reproducible OS, IaC-style deploys, local AI, MCP workstation. Home lab also shows **hardware and OS internals** (BIOS, OC/undervolt, kernel, Windows registry, workload tuning) — breadth beyond servers and a terminal session.

The workstation kit is **OS-agnostic**: bash, Docker, `chmod 600` env files, `mcp.json`. It ran on **WSL2**, then **native Linux**, and copies onto **macOS or any Linux** the same way. Windows is one possible host, not a requirement.

| Path | Topic |
|------|-------|
| [`workstation/`](workstation/) | MCP + scripts + Replicate/local models: stand up the engineer loop on a new laptop (Linux, macOS, or WSL) |
| [`home-lab/`](home-lab/) | Dual-boot workstation, hardware/BIOS, kernel/registry, local LLM/SD, Ansible edge, Android SSH |

Site section title: **Practice** (never "Hobbies").

Sanitized code sits next to the pages: [`home-lab/reference/`](home-lab/reference/), [`workstation/reference/`](workstation/reference/). Ansible kits: [`../iac/ansible/reference/`](../iac/ansible/reference/). Cluster Helm lives in [`../iac/helm/`](../iac/helm/), not under home-lab.
