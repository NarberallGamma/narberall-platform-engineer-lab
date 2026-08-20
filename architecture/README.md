# Architecture cases (for managers)

Leads and founders do not read a thousand lines of Terraform. These pages are **short architectural reviews**: one diagram, one business sentence, links into the existing lab. Nothing below replaces [`../case-studies/`](../case-studies/) or [`../diagrams/`](../diagrams/). Those stay the source of the longer stories and the mermaid already published.

Diagrams live in git as **Mermaid** (GitHub renders them; same idea as Eraser / Structurizr C4: boxes and flows, not a slide pack). Export to SVG later if a site needs it.

Leitmotif: [`../docs/for-business.md`](../docs/for-business.md). Headline is **full infra, fast, documented, short windows, high SLA**. Cloud move is one page, not the first ask.

| Page | Audience question | Existing proof |
|------|-------------------|----------------|
| [Days, not months](00-days-not-months.md) | How fast is a usable platform, and is it written down? | Cases 02, 05, 06, 07, 11, CI catalog |
| [LLMOps / AI](01-llmops.md) | Why GPU and OCR, and why a multi-agent desk is part of the platform? | Cases 01, 03, `practice/home-lab/reference/ai/`, `practice/workstation/` (Cursor / Claude / Codex / local) |
| [SRE / monitoring](05-sre.md) | How does on-call see a breach, and how fast is a new Grafana view? | [`../docs/sre/`](../docs/sre/), cases 10–11, PromRules, ElastAlert2, Ansible VM |
| [Product APIs](06-product-apis.md) | How does accompany talk to Grafana, Vault, Argo, JSM without a week of click-ops? | Workstation scripts, [`../docs/security-ai.md`](../docs/security-ai.md) |
| [FinOps / night park](02-finops-night-park.md) | How does the bill drop without a rewrite? | Huawei-class schedule pattern |
| [Reusable units](03-reuse-modules.md) | What can be applied again next week? | `iac/terraform/modules`, AWS live, GitLab CI, [`../iac/ansible/`](../iac/ansible/), [`../iac/helm/`](../iac/helm/), [`../iac/helm/apps/`](../iac/helm/apps/) |
| [Cloud move](04-seamless-move.md) | When we must change clouds, can the freeze stay hours? | VK + Huawei-class trees (one skill among many) |

```mermaid
flowchart TB
  Biz[Business outcome] --> Days[Days to baseline]
  Biz --> Bill[Lower idle bill]
  Biz --> AI[Faster document and analysis loops]
  Days --> TF[Existing iac/terraform]
  Days --> ANS[Existing iac/ansible]
  Days --> HELM[Existing iac/helm]
  Bill --> Park[Night park / right-size]
  AI --> OCR[OCR plus LLM]
  AI --> Desk[Multi-agent MCP desk]
  Biz --> SRE[On-call views same day]
  SRE --> Obs[Helm overlay plus Ansible scrape]
  SRE --> APIs[Grafana Vault Argo JSM GitLab]
```
