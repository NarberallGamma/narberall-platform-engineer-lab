# Terraform eras

Compare how my IaC looked over time. All paths are under [`../`](../) (repo `terraform/`).

| Era | Path | Code location |
|-----|------|----------------|
| **Current** | [`current-cloud-ru/`](current-cloud-ru/) | Mostly `stacks/` + `modules/` |
| **Legacy AWS** | [`legacy-aws/`](legacy-aws/) | Self-contained `.tf` samples here |
| **Legacy Selectel** | [`legacy-openstack-selectel/`](legacy-openstack-selectel/) | Self-contained `.tf` samples here |

```mermaid
flowchart TB
  subgraph current [Current]
    M[modules]
    S[stacks]
  end
  subgraph legacy [Legacy_Flant_era]
    AWS[legacy-aws]
    SEL[legacy-openstack-selectel]
  end
  current --> Hunter[Hunter reads eras first]
  legacy --> Hunter
```
