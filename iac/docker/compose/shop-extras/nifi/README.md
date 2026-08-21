# NiFi (host compose)

**Business first:** a laptop or jump-host NiFi is **one service, HTTPS 8443, single-user**, not the cluster chart. Kit: [`../`](../). Hub: [`../../../`](../../../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md). Image (JDBC + cacerts): [`../../../images/apps/nifi/`](../../../images/apps/nifi/). Helm: [`../../../../helm/reference/helm-data-plane/nifi/`](../../../../helm/reference/helm-data-plane/nifi/).

I used this file when the shop needed a host NiFi before the chart. Image `apache/nifi:2.6.0`. Proxy host `nifi.dev.example.com`. Password `CHANGE_ME`.

```text
nifi/
  docker-compose.yml    # apache/nifi:2.6.0, 8443, SINGLE_USER_CREDENTIALS_*
```

```bash
# from this directory, after setting SINGLE_USER_CREDENTIALS_PASSWORD:
docker compose up -d
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Same pin as Helm | `2.6.0` on compose, image, and chart |
| `NIFI_WEB_PROXY_HOST` | Ingress-shaped host on a compose file |
| Single-user env | No LDAP block in this mechanic |

## Honest gap

This compose does **not** build [`../../../images/apps/nifi/`](../../../images/apps/nifi/). There is no JDBC jar and no `cacerts` unless that image is built and the `image:` line is retargeted. Password must be set before a useful login.

**Keywords:** NiFi 2.6.0, single-user, 8443, host compose
