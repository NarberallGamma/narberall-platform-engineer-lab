# Payments identity platform autodeploy (Swarm, then Kubernetes)

Sanitized Ansible tree for an **SBP-class payments identity plane**. Access Manager (AM), Identity Gateway (IG / IGext on YARP), Redis / KeyDB, Postgres, and operator docs go out as one playbook. The first target is **Docker Swarm**. The same product roles later call `k8s_service` (Deployment / StatefulSet / Service / Secret) instead of `docker_service`.

This is **application autodeploy**, not host bootstrap. Host baseline stays in [`../ansible-bootstrap/`](../ansible-bootstrap/). Hunter map: [`../../iac/ansible/`](../../iac/ansible/). Case study: [`../../case-studies/08-payments-swarm-autodeploy.md`](../../case-studies/08-payments-swarm-autodeploy.md).

Brand, registry, inventory users, PFX, and live passwords are stripped. Role logic, Jinja, realm JSON, and YARP samples stay almost intact so an AI (or a reviewer) can parse a real autodeploy, not a three-task demo.

```text
ansible-payments-idplat/
  all.yml                 # full stack on swarm_manager
  all_ig.yml am.yml ig.yml igext.yml
  redis.yml idplat_postgres.yml deploydocs.yml
  roles/
    docker_service/       # Swarm engine: render, deploy, check
    k8s_service/          # same contract for Kubernetes
    network redis am amcli ig igext
    idplat_postgres deploydocs base
  inventories/dev/
    hosts.ini.example
    group_vars/all/       # images, DB, global, passwd.yaml.example
    am_realm/             # OIDC / JWT / LDAP / Windows demo realms
    ig_customs/           # YARP reverse-access, metrics, tracing
    certs/README.md       # PFX names only; files stay local
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| `docker_service` + `k8s_service` | One variable contract (`deploy_to_k8s`). Child roles dump vars, then include the parent engine. |
| `all.yml` | Ordered stack: overlay network, Redis, IG, optional IGext, Postgres wait-until-Running, AM first-deploy via `amcli`, then AM service. |
| `amcli` | First-boot / plugin / migration job as a Swarm service that must reach Complete, then is removed unless debug stays on. |
| Realms + YARP | OIDC, JWT, client-credentials, PKCE, LDAP bind, Windows/Kerberos modules. Not a hello-world inventory. |
| `prepare_only` | Render configs to `output_dir` without touching Swarm / the cluster. |

```bash
cp inventories/dev/hosts.ini.example inventories/dev/hosts.ini
cp inventories/dev/group_vars/all/passwd.yaml.example inventories/dev/group_vars/all/passwd.yaml
# place PFX / PEM next to inventories/dev/certs/README.md
ansible-galaxy collection install -r requirements.yml
ansible-playbook -i inventories/dev/hosts.ini all.yml
# later, same roles:
# ansible-playbook -i inventories/dev/hosts.ini all.yml -e deploy_to_k8s=true
```

## Playbooks

| Playbook | Scope |
|----------|-------|
| `all.yml` | Full identity platform on `swarm_manager` |
| `all_ig.yml` | Gateway pair only |
| `am.yml` / `ig.yml` / `igext.yml` | Single product role |
| `redis.yml` / `idplat_postgres.yml` / `deploydocs.yml` | Data plane and operator docs |

## Roles

| Role | Job |
|------|-----|
| `network` | Overlay / attach networks the stack needs |
| `redis` | Cache for IG (test Redis from this tree; prod uses an external Redis) |
| `ig` / `igext` | Identity Gateway and external reverse-access instance (YARP) |
| `idplat_postgres` | AM configuration database (skipped when `deploy_to_k8s`) |
| `am` / `amcli` | Access Manager service and first-deploy / migration CLI |
| `deploydocs` | Bundled operator documentation service |
| `docker_service` | Swarm: require, prepare, render, deploy, check |
| `k8s_service` | Kubernetes: same steps, different templates |
| `base` | Shared defaults |

## Inventory contract

- Images: `inventories/dev/group_vars/all/image.yaml` (generic registry `registry.example.com:5000`)
- Hostname: `idplat_public_hostname` in `identityplatform_global.yaml`
- Secrets: copy `passwd.yaml.example` (never commit the live file)
- TLS: names in `inventories/dev/certs/README.md`

## Keywords

Ansible, Docker Swarm, Kubernetes, YARP, OIDC, JWT, Access Manager, Identity Gateway, Redis, Postgres, first-deploy, SBP-class, payments identity
