# Vault + nginx (host bridge)

**Business first:** a single-node Vault is **static IPs on a user-defined bridge**, not a Raft trio. Hub: [`../../`](../../). Sanitize: [`../../SANITIZE.md`](../../SANITIZE.md). Estate Raft sibling: [`../../../ansible/reference/ansible-estate/roles/vault-docker/`](../../../ansible/reference/ansible-estate/roles/vault-docker/).

I used this pair on two VMs: DEV `hashicorp/vault:2.0.2` and PROD `2.0.3` with an extra `dns` list. Same topology: `IPC_LOCK`, `vault server -config=/vault/config/vault.hcl`, nginx on :80/:443, addresses `.2` / `.3` on `10.10.18.0/24`. `vault.hcl` and the nginx server blocks are not in git.

```text
vault/
  docker-compose.dev.yml    # Vault 2.0.2 + nginx, static 10.10.18.2 / .3
  docker-compose.prod.yml   # Vault 2.0.3 + nginx, same IPs, dns 10.10.1.9
```

```bash
# from this directory, after config/vault.hcl, ssl/, data/, and the nginx vhost exist:
docker compose -f docker-compose.dev.yml up -d
docker compose -f docker-compose.prod.yml up -d
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| User-defined bridge + static IPs | nginx talks to Vault by address, not by published 8200 |
| `IPC_LOCK` | mlock for the server process |
| Host CA bundle | `/etc/ssl/certs` read-only into the Vault container |
| DEV vs PROD files | Pin `2.0.2` vs `2.0.3`. PROD adds `dns: 10.10.1.9` on both services |

This is **not** [`../../../ansible/reference/ansible-estate/roles/vault-docker/`](../../../ansible/reference/ansible-estate/roles/vault-docker/). That role publishes 8200/8201, has a healthcheck, and has no nginx sidecar. This folder is the host pattern with a front proxy and pinned IPs.

## Honest gap

`vault.hcl`, `vault-dev.example.com.conf` / `vault.example.com.conf`, TLS under `./ssl`, and `./data` are not in this folder. Volume names are placeholders. A `compose up` from this directory alone starts empty processes that exit on a missing config.

**Keywords:** Vault, nginx, IPC_LOCK, static IP, user-defined bridge
