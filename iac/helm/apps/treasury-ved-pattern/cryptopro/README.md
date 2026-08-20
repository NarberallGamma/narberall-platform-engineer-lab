# CryptoPro (thin PVC + keep)

**Business first:** this service only needs the CSP directory on disk. I used one **100Mi** `cprocsp` claim with `lookup` and `keep`, and I did not add a bootstrap script. Hub: [`../../../`](../../../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md). Shared library: [`../_libs/base-chart/`](../_libs/base-chart/).

I published the umbrella overlay only. Shared `base-chart` 0.2.1 lives in [`../_libs/base-chart`](../_libs/base-chart) (`file://`). I did not vendor a second copy.

```text
cryptopro/
  Chart.yaml
  values.yaml
  .gitignore                         # charts/ and Chart.lock stay out
  templates/
    _helpers.tpl
    external-secret.yaml
    pvc.yaml                         # lookup + keep, 100Mi, mount /var/opt/cprocsp
```

Create runs only when the claim is missing. After the first deploy, set `persistence.cprocsp.create: false` and keep the same `claimName` in `extraVolumes`. `strategy: Recreate` matches the single RWO volume.

No Kafka. Postgres URL in values is a documentation address. Credentials come from ExternalSecret (`spring.datasource.*`, `spring.flyway.*`).

I do not ship `Chart.lock`. Fetch the library from this directory:

```bash
helm dependency update
helm template cryptopro . --namespace estate
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Thin PVC | Whole `/var/opt/cprocsp`, not users/keys/dsrf split |
| lookup + keep | Same adopt-or-create idea as policy-gateway, without init |
| No bootstrap | Contrast with the two gateway overlays |
| ExternalSecret | DB user/password only |

## Sanitize

Hosts are `*.example.com`. Image is `example.registry/estate/cryptopro`. Vault is `https://vault.example.com`. JDBC host is `10.10.0.10`. ESO remote key is `secret/cryptopro-app`. ExternalSecret namespace is `estate`.

**Keywords:** CryptoPro, Helm overlay, PVC lookup, keep, External Secrets
