# Estate integration (ExternalSecret sample)

**Business first:** a partner payment-rail adapter is not another auth clone. The hunter artefact is the **per-service ExternalSecret**: twelve keys, two Vault paths, passphrases next to a separate TLS Secret. Buyer page: [`../../../../../docs/for-business.md`](../../../../../docs/for-business.md). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).

I published the umbrella overlay only. Shared `base-chart` is `file://../_libs/base-chart` (owned next to [`../estate-auth/`](../estate-auth/)). I did not vendor a second copy of that library.

```text
integration-secret/
  Chart.yaml                      # estate-integration 0.1.0, base-chart 0.2.1 via file://
  values.yaml                     # Istio sidecar, Kafka SASL_SSL, partner TLS init, ingress
  templates/
    external-secret.yaml          # 12 keys, secret/estate-kafka + secret/estate-integration-adapter
    _helpers.tpl
```

Render after the shared lib exists:

```bash
helm dependency update
helm template estate-integration . -n estate
```

## Why this ExternalSecret is richer than estate-auth

[`../estate-auth/`](../estate-auth/) is the canon umbrella: same `base-chart`, same ClusterSecretStore, same shared Kafka path. Its ExternalSecret is **seven** keys: `kafkaClientPassword`, four datasource/Flyway fields, and a JWT key pair. That is identity material for one service.

This overlay is the integration SAMPLE. The ExternalSecret is **twelve** keys on the same `secret/<name>` Vault shape, still two remote paths, but the app path is a partner contract, not a key pair.

| | [`../estate-auth/`](../estate-auth/) | this kit |
|--|--|--|
| Data entries | 7 | 12 |
| Shared path | `secret/estate-kafka` | `secret/estate-kafka` |
| App path | DB + Flyway + public/private key | DB + Flyway + nominal-account id + signer URL + partner URL + signer certificate id + monthly OAuth token + PFX passphrase + truststore passphrase |
| Binary TLS | none | out-of-band Secret `estate-integration-tls-files` (`client.pfx`, `truststore.jks`). Init copies into emptyDir `/opt/partner/tls/certs`. Not mixed into the text ExternalSecret |

I kept Vault path shape (`secret/...` plus a Spring-style `property`). Live mounts and product names are placeholders. ClusterSecretStore name stays `vault-cluster-secret-store` so it matches the estate Vault wrap.

I did **not** copy the eighteen root `*-global-values-external-secret.yaml` bodies. Those are a cluster Merge generator, a different unit. This folder is the one richest per-service list.

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Twelve-key ExternalSecret | Partner URL, signer, certificate id, OAuth token, two TLS passphrases. Longer than auth on purpose |
| Two Vault paths | Shared Kafka password plus an app-specific KV. Same store, different secret objects |
| Text vs binary split | Passphrases in ESO. PKCS#12 and JKS stay in a dedicated Secret so the vault-secrets object stays string keys |
| Secret + emptyDir TLS | Partner mTLS without a PVC. Same pattern as the Kafka truststore init next to it |
| Dual Vault clients | Pod consumes ESO via `extraEnvFrom`. Spring Cloud Vault is still on (`authDelegator: true`) for app-initiated reads |
| Overlay only | Chart.yaml, values, two templates. No vendored `base-chart`, no `.tgz` |

Kafka truststore init (JKS from `kafka-ca-cert`) is here because the adapter is on the same SASL_SSL bootstrap as the rest of the estate. The websocket SAMPLE owns the values-only truststore story. I left both inits because the partner TLS bootstrap is the extra mechanic.

## Shared chart (not vendored)

| Chart | Pin | What I changed | In git |
|-------|-----|----------------|--------|
| base-chart | 0.2.1 | `repository: file://../_libs/base-chart`, alias `application` | pointer only |

`helm dependency update` fills `charts/` locally. That unpacked tree stays out of git.

## Sanitize

Hosts are `*.example.com`. Brokers are `kafka-0.example.com` and siblings. JDBC uses `10.10.0.10`. Images are `example.registry/...`. Vault address is `https://vault.example.com`. KV paths are `secret/estate-kafka` and `secret/estate-integration-adapter`. Copy strings and payment-purpose lines are `CHANGE_ME`.

**Keywords:** External Secrets, Vault, Helm overlay, Kafka SASL_SSL, partner TLS, emptyDir, nominated account
