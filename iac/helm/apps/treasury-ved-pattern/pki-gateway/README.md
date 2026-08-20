# PKI gateway (three PVC + Files.Get)

**Business first:** PKI keeps CryptoPro **users**, **keys**, and **pkidebug** on three claims. I loaded the bootstrap script with `.Files.Get`, not an inline `bash -c`. Hub: [`../../../`](../../../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md). Shared library: [`../_libs/base-chart/`](../_libs/base-chart/).

I published the umbrella overlay only. Shared `base-chart` 0.2.1 lives in [`../_libs/base-chart`](../_libs/base-chart) (`file://`). I did not vendor a second copy.

```text
pki-gateway/
  Chart.yaml
  values.yaml
  .gitignore                         # charts/ and Chart.lock stay out
  scripts/bootstrap-cryptopro.sh
  templates/
    _helpers.tpl
    bootstrap-script-configmap.yaml  # .Files.Get scripts/bootstrap-cryptopro.sh
    external-secret.yaml
    pvc.yaml                         # users + keys + pkidebug, create flags
```

This is not a subset of policy-gateway. Policy uses one volume, a named init define, and a keys-import switch. Here the init container is listed in values, GENKEY skips generation, and each CSP path has its own 1Gi claim.

| Claim (default) | Mount |
|-----------------|-------|
| `pki-gateway-cprocsp-users-pvc` | `/var/opt/cprocsp/users/cprouser` |
| `pki-gateway-cprocsp-keys-pvc` | `/var/opt/cprocsp/keys/cprouser` |
| `pki-gateway-pkidebug-data-pvc` | `/app/data/pkigateway` |

Existing volumes: set `persistence.*.create: false` and keep the same `claimName`. There is no `lookup` / `keep` on these three claims (that mechanic is policy-gateway and the thin cryptopro chart).

Spring property `treasury.policy-gateway.dgtry.mode=GENKEY` stays; the script reads it. cert-verifier is only a Feign URL in values. That service is not in this slice.

I do not ship `Chart.lock`. Fetch the library from this directory:

```bash
helm dependency update
helm template pki-gateway . --namespace estate
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Three PVCs | Users, keys, and debug data stay independent |
| `.Files.Get` | Script lives in git; ConfigMap is generated |
| values `initContainers` | Overlay bootstrap without `_initcontainers.tpl` |
| GENKEY | chown only; `cpro_genkeys.sh` does not run on every start |
| ExternalSecret | dgtry pin from Vault, not from plain values |

## Sanitize

Hosts are `*.example.com`. Images are `example.registry/...`. Vault is `https://vault.example.com`. ESO remote key is `secret/pki-gateway-app`. ExternalSecret namespace is `estate`.

**Keywords:** CryptoPro, Helm overlay, three PVC, Files.Get, External Secrets, GENKEY
