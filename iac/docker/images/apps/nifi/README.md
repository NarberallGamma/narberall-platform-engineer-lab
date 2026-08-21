# NiFi packaging image

**Business first:** shop document flows ride a **pinned Apache NiFi** with a JDBC driver in `lib/`, not a laptop `docker pull` of `latest`. Hub: [`../../../`](../../../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md). Host compose: [`../../../compose/shop-extras/nifi/`](../../../compose/shop-extras/nifi/). Cluster chart: [`../../../../helm/reference/helm-data-plane/nifi/`](../../../../helm/reference/helm-data-plane/nifi/).

I used this Dockerfile when the shop needed Postgres from NiFi processors. The image is `apache/nifi:2.6.0` plus `postgresql-42.7.8.jar`. The JVM `cacerts` copy is the operated shape. The truststore file is not in git.

```text
nifi/
  Dockerfile    # apache/nifi:2.6.0, curl JDBC jar, COPY cacerts
```

```bash
# from this directory, after a local cacerts file is next to the Dockerfile:
docker build -t example.registry/shop-app/nifi:2.6.0 .
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Pin `2.6.0` | Same tag as the Helm chart and the host compose |
| JDBC in `lib/` | Processors talk to shop Postgres without a manual jar drop |
| `COPY cacerts` | Estate TLS into the Bellsoft JDK path used on that image |

## Honest gap

`cacerts` is not in this folder. `docker build` from this directory alone fails on the `COPY`. I did not invent a placeholder truststore.

This file is the **image**. The single-user host stack is [`../../../compose/shop-extras/nifi/`](../../../compose/shop-extras/nifi/). The PVC and Ingress release is the Helm tree.

**Keywords:** NiFi 2.6.0, PostgreSQL JDBC, cacerts, packaging
