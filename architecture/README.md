# Architecture cases (for managers)

Leads and founders do not read a thousand lines of Terraform. These pages are **short architectural reviews**: one diagram, one business sentence, links into the existing lab. Nothing below replaces [`../case-studies/`](../case-studies/) or [`../diagrams/`](../diagrams/). Those stay the source of the longer stories and the mermaid already published.

Diagrams live in git as **Mermaid** (GitHub renders them; same idea as Eraser / Structurizr C4: boxes and flows, not a slide pack). Export to SVG later if a site needs it.

Leitmotif: [`../docs/for-business.md`](../docs/for-business.md).

| Page | Audience question | Existing proof |
|------|-------------------|----------------|
| [Days, not months](00-days-not-months.md) | How fast is a usable platform? | Cases 02, 05, 06, 07, CI catalog |
| [LLMOps / AI](01-llmops.md) | Why GPU and OCR, not a toy chat? | Cases 01, 03, `reference/ai/` |
| [FinOps / night park](02-finops-night-park.md) | How does the bill drop without a rewrite? | Huawei-class schedule pattern |
| [Reusable units](03-reuse-modules.md) | What can be applied again next week? | `iac/terraform/modules`, AWS live, GitLab CI |
| [Cloud move](04-seamless-move.md) | Can we change clouds without a year of freeze? | VK + Huawei-class trees, planned Advanced cutover |

```mermaid
flowchart TB
  Biz[Business outcome] --> Days[Days to baseline]
  Biz --> Bill[Lower idle bill]
  Biz --> AI[Faster document and analysis loops]
  Days --> TF[Existing iac/terraform]
  Bill --> Park[Night park / right-size]
  AI --> OCR[OCR plus LLM]
```
