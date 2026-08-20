# Policy gateway (one PVC + init)

**Business first:** CryptoPro keys and RocksDB share **one** RWO volume. I used Helm `lookup` plus `helm.sh/resource-policy: keep` so a sync does not wipe wallets. Hub: [`../../../`](../../../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md). Shared library: [`../_libs/base-chart/`](../_libs/base-chart/).

I published the umbrella overlay only. Shared `base-chart` 0.2.1 lives in [`../_libs/base-chart`](../_libs/base-chart) (`file://`, owned once). I did not vendor a second copy.

```text
policy-gateway/
  Chart.yaml
  values.yaml
  .gitignore                         # charts/ and Chart.lock stay out
  scripts/bootstrap-cryptopro-keys.sh
  templates/
    _helpers.tpl
    _initcontainers.tpl              # prepare-data-dirs, bootstrap, create-truststore
    bootstrap-script-configmap.yaml  # .Files.Get of the script
    external-secret.yaml
    pvc.yaml                         # lookup + keep, 32Gi, subPath mounts
```

Init list is not inline in values. `application.initContainersTemplate` points at `policy-gateway.initContainers`. That define picks the hsm-bootstrap image when `keysImport.enabled` is true, otherwise the CryptoPro image for PREGEN.

| Init | Role |
|------|------|
| prepare-data-dirs | mkdir subPath tree, `chown 10001` |
| bootstrap | optional `keys.tar.gz` import, then vendor PREGEN / skip |
| create-truststore | Kafka CA from Secret into JKS on emptyDir |

`strategy: Recreate` because one RWO claim cannot Multi-Attach. 32Gi is an inode choice, not a capacity guess: thousands of `dgtry_mk_*` dirs exhaust ext4 inodes on 8Gi before the disk fills. Resize does not add inodes.

Spring property names (`treasury.policy-gateway.dgtry.mode`) stay as the bootstrap script reads them.

The shared `_libs/base-chart` renders either a YAML `initContainers` list or `initContainersTemplate` (`include` of a named define). This overlay uses the template path. I did not vendor a second `base-chart`.

I do not ship `Chart.lock`. Fetch the library from this directory:

```bash
helm dependency update
helm template policy-gateway . --namespace estate
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| One PVC + subPath | RocksDB `data` and CryptoPro users/keys/dsrf on the same claim |
| lookup + keep | Adopt an existing claim; Helm/Argo must not prune it |
| `_initcontainers.tpl` | Overlay owns init; base-chart only includes the define |
| keysImport switch | Restore from archive vs generate on empty PVC |
| ExternalSecret | Kafka password, S3 keys, CSP pin and license from Vault |

## Sanitize

Hosts are `*.example.com`. Images are `example.registry/...`. Kafka bootstrap is `kafka-0.example.com:9093`. Vault is `https://vault.example.com`. ESO remote keys are `secret/estate-kafka` and `secret/policy-gateway-app`. ExternalSecret namespace is `estate`.

**Keywords:** CryptoPro, Helm overlay, PVC lookup, initContainersTemplate, RocksDB, External Secrets
