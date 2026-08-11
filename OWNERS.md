# Ownership (work machine vs home machine)

This repository is maintained from **two machines**. Edit only your zone.

## Work machine (primary portfolio)

**Owns:**

- `README.md`, `docs/`, `site/`, `packages/`
- `case-studies/` (client-derived, NDA-safe narratives)
- `practice/workstation/`
- `reference/` (except paths marked `HOME_SLOT`)
- `diagrams/case-studies/` and shared diagrams

**Must:**

- Leave `HOME_SLOT` stubs empty of invented home hardware facts
- Sanitize: no client hostnames, IPs, secrets, ticket IDs
- English in all public markdown
- Practice ≤ ~20% of site weight vs case studies
- Follow `docs/content-guide.md` (no em dashes; personal voice; ATS keywords)

## Home machine

**Owns only:**

- `practice/home-lab/**`
- `diagrams/practice/home-lab/**`
- optional `reference/apps/home-*` or files with `<!-- HOME_SLOT -->`

**Must not:**

- Rewrite case studies, packages, site hero, or workstation practice
- Commit VPN credentials, home LAN IPs, personal passwords
- Dump unrelated entertainment media

**Should:**

- Fill real facts: Arch/Windows dual-boot, Ollama/vLLM models, pet project one-liners
- Add one short diagram for local AI or dual-boot topology
- Link pet projects from `practice/home-lab/pet-projects.md`

## Marker

```html
<!-- HOME_SLOT: fill on home machine only. Do not invent hardware facts on work machine. -->
```
