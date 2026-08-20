# Estate Keycloak (Helm overlay)

**Business first:** SSO is an **overlay**, not an 84-file vendor tree. Buyer page: [`../../../../docs/for-business.md`](../../../../docs/for-business.md). Case: [`../../../../case-studies/11-helm-estate.md`](../../../../case-studies/11-helm-estate.md).

I used this umbrella when Keycloak 26 sat on **managed** Postgres (RDS-class). Helm owned ingress, Quarkus health on :9000, and one ExternalSecret. The identity chart stayed a pin. ClusterSecretStore lives in the estate Vault wrap, not here.

Brand, live FQDNs, JDBC hosts, Vault paths, and pull-secret names are stripped. Parent templates stay so a reviewer can parse the ExternalSecret, not a codecentric tarball.

Hub: [`../../`](../../). Sanitize: [`../../SANITIZE.md`](../../SANITIZE.md). Vault thin wrap: [`../../reference/helm-estate-cluster/vault/`](../../reference/helm-estate-cluster/vault/).

```text
treasury-keycloak/
  Chart.yaml                      # estate-keycloak; depends on codecentric keycloak 17.0.2
  values.yaml                     # image 26.0.6, postgresql.enabled false, ESO refs
  templates/
    _helpers.tpl
    external-secret.yaml          # KC_DB_PASSWORD + KEYCLOAK_ADMIN_PASSWORD
```

Render (after `helm dependency build` in this directory):

```bash
helm template estate-keycloak . -n estate
```

## Who this page is for

Hiring lead: this is the only Keycloak product chart I am publishing. Engineer: vendor `charts/keycloak/` and the Bitnami PostgreSQL subchart stay out on purpose.

## What this kit is / is not

It is a thin parent chart: values + one ExternalSecret. It is not a vendored Bitnami or codecentric tree, not an in-cluster Postgres operator, and not a custom theme image.

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Overlay only | Chart.yaml + values + two parent templates. 84-file `charts/keycloak/` is a NOTES pin |
| External Postgres | `postgresql.enabled: false`, JDBC to `10.10.x.x`, `sslmode=require` |
| ExternalSecret | Two keys from Vault via ClusterSecretStore. Admin password is `valueFrom`, DB password arrives through `extraEnvFrom` |
| Keycloak 26 on an older chart | Image `quay.io/keycloak/keycloak:26.0.6` with `start` / health flags, probes on management port 9000 |
| Ingress | nginx, TLS ACME, hostname `keycloak.example.com` |

## Vendor charts (documented, not vendored)

| Chart | Pin (as used) | What I changed | In git |
|-------|---------------|----------------|--------|
| codecentric keycloak | **17.0.2** | Image 26.0.6, embedded PG off, RDS JDBC, ESO, nginx ingress, Quarkus probes on :9000 | overlay only |
| Bitnami postgresql | 10.3.13 (subchart of 17.0.2) | `postgresql.enabled: false` | not copied |

`helm dependency build` pulls 17.0.2 from `https://codecentric.github.io/helm-charts`. The estate copy used `file://./charts/keycloak` and is not in this repo.

The Chart.yaml inside that vendored tree is **codecentric** 17.0.2. Bitnami appears only as the unused PostgreSQL subchart.

## Secrets

ExternalSecret `estate-keycloak-vault-secrets` reads `secret/estate-keycloak` (`KC_DB_PASSWORD`, `KEYCLOAK_ADMIN_PASSWORD`). ClusterSecretStore name matches the estate Vault wrap: `vault-cluster-secret-store`.

## Sanitize

[`../../SANITIZE.md`](../../SANITIZE.md). Hosts are `*.example.com`. JDBC uses `10.10.x.x`. Passwords, realm client secret, DB user, and pull secrets are `CHANGE_ME`. No PEM, no `secret-values.yaml`, no vendor tree.

**Keywords:** Keycloak, Helm overlay, External Secrets, Vault, PostgreSQL, codecentric, Bitnami, ingress-nginx
