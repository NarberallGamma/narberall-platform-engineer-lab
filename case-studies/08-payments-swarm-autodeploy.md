# Case study: SBP-class identity plane autodeploy (Swarm, then Kubernetes)

**Context:** bank / SBP-class payments identity (OIDC / JWT / realms), Docker Swarm first  
**Timeline:** autodeploy of the identity stack, then the same roles adapted for Kubernetes  
**Role:** Platform Engineer (Ansible owner for the identity plane)

This is **proof** that the Ansible half of the lab is not only VPS bootstrap and an edge panel. A payments identity platform (Access Manager + Identity Gateway on YARP + Redis + Postgres) is declared as inventory + roles. Swarm is the first engine. `deploy_to_k8s` switches the parent role to Kubernetes objects without rewriting the product roles.

Not a claim to have designed the national SBP switch. The public story is sector and class: identity in front of a payments estate.

## Challenge

The identity plane is not one container. First deploy must create realms, apply plugins, run migrations, wait until a Swarm service is Running or Complete, then remove the CLI job unless debug stays on. Gateway can run as a pair (internal + external reverse-access). TLS material and DB passwords must stay out of git. Later the same stack had to land on Kubernetes without a second, unrelated playbook tree.

## Architecture

See diagram: [`diagrams/case-studies/08-payments-swarm-autodeploy.md`](../diagrams/case-studies/08-payments-swarm-autodeploy.md)

```text
1) Inventory: images, hostname, realms, YARP customs, cert names
2) network role: overlay / attach
3) redis (when IG cache is Redis)
4) ig + optional igext (ReverseAccess)
5) postgres (Swarm only) and wait-until-Running
6) amcli first-deploy / plugins / migrations, wait-until-Complete
7) am service; deploydocs
8) Same child roles + k8s_service when deploy_to_k8s=true
```

Honest scope: host OS, Docker CE, and SSH harden are [`iac/ansible/reference/ansible-bootstrap/`](../iac/ansible/reference/ansible-bootstrap/). This tree assumes a Swarm manager (or a kube context) already exists.

## What shipped

- Full role set: `docker_service`, `k8s_service`, AM, AM CLI, IG, IGext, Redis, Postgres, docs
- Playbooks for the full stack and for single components
- Demo realms: authorization code, PKCE, client credentials, implicit, LDAP, Windows/Kerberos modules
- YARP samples: reverse-access, metrics, distributed tracing
- Public lab: brand and secrets stripped; technical code kept

## Results

- One inventory drives Swarm today and Kubernetes later
- First-boot is a coded job with retries, not a wiki of docker commands
- Reviewers and automated parsers see a real autodeploy graph, not a truncated sample

## Stack

Ansible, Docker Swarm (`docker_swarm_service` / stack), Kubernetes (Deployment / StatefulSet / Service / Secret), YARP, OIDC, JWT, Redis, Postgres, PFX-backed TLS (local only)

## Links

- Sanitized code: [`iac/ansible/reference/ansible-payments-idplat/`](../iac/ansible/reference/ansible-payments-idplat/)
- Ansible hub: [`iac/ansible/`](../iac/ansible/)
- Payments narrative: [`docs/experience.md`](../docs/experience.md)
- Host baseline (separate): [`iac/ansible/reference/ansible-bootstrap/`](../iac/ansible/reference/ansible-bootstrap/)
