# Diagrams

**Managers first:** short architecture reviews (days, LLMOps, FinOps, reuse, cloud move) live under [`../architecture/`](../architecture/). Case mermaid in this folder stays the long-form source. More diagrams can be added later without moving these files.

Prefer SVG/PNG from Excalidraw/draw.io, or Mermaid next to the case / practice page.

| Path | Use |
|------|-----|
| [`case-studies/`](case-studies/) | Architecture for published case studies (01-09, including Selectel VPC + dedicated Proxmox) |
| [`iac/`](iac/) | CI turnkey (Jenkins + GitLab CI, build/publish/revoke) |
| [`practice/home-lab/`](practice/home-lab/) | Dual-boot, local AI, Ansible edge, Android SSH |

Code those diagrams point at: [`../iac/`](../iac/) (cloud, terraform, ansible, ci), [`../reference/`](../reference/), [`../practice/`](../practice/).

No real IPs or client hostnames in labels.
