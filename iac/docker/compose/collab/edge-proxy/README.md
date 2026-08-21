# Edge nginx (host network)

**Business first:** the edge is **host-net nginx with its own logs and conf**, not an ingress object. Hub: [`../../../`](../../../). Collab index: [`../`](../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md). Estate WAF sibling: [`../../../../ansible/reference/ansible-estate/infra/nginx-waf/`](../../../../ansible/reference/ansible-estate/infra/nginx-waf/).

I used `nginx:1.27.4` on `network_mode: host` so vhosts bind host :80/:443. Conf, certs, and logs are four binds. json-file is 50m×1.

```text
edge-proxy/
  docker-compose.yml    # host-net nginx 1.27.4
```

```bash
# from this directory, after ./config, ./certs, ./logs, and nginx.conf exist:
docker compose up -d
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| `network_mode: host` | Same ports as a VM nginx unit |
| Split binds | `conf.d`, certs, logs, and the main `nginx.conf` |
| Tight log rotate | 50m × 1 file |

## Honest gap

`nginx.conf`, `./config` vhosts, and certs are not in git. Estate WAF compose lives under Ansible, not in this folder.

**Keywords:** nginx, host network, edge proxy
