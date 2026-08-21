# Ansible execution environment (CI)

**Business first:** playbooks that talk to Vault and Postgres run in a **pinned** image so a worker does not pick a random ansible-core.

I used this image on GitLab jobs for estate playbooks (prepare servers, Vault, db_restore, node-exporter, bootstrap users). It is Alpine 3.20 plus ansible-core **2.16.x**, `hvac`, and Galaxy collections including `community.hashi_vault`. It is **not** `ansible/creator-ee`.

The other variant already in this lab is [`../../../../ansible/reference/ansible-runner/`](../../../../ansible/reference/ansible-runner/): unpinned `ansible-core`, `passlib`, `jmespath`, no `hvac` / `community.hashi_vault`. That image is for host wrappers (`run_prepare.sh` / `run_edge.sh`). This folder is the CI pin with Vault lookup. I did not overwrite the runner kit.

```text
ansible-ee/
  Dockerfile
  requirements.yml    # includes community.hashi_vault >=7
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| `ansible-core>=2.16,<2.17` | Pin. A later core (2.20+) died on NTFS mounts in one CI agent. |
| `hvac` + `community.hashi_vault` | Vault lookups in the image, not a later pip on the runner. |
| Same Galaxy set as the runner, plus Vault | `community.general`, `docker`, `postgresql`, `ansible.posix`, `community.crypto` |
| Not creator-ee | Slim Alpine, not a Red Hat EE |

```bash
docker build -t example.registry/ci/ansible-ee:2.16 -f Dockerfile .
```

Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).
