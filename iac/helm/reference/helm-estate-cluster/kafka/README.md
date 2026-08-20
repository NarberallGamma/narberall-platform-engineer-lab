# Estate Kafka Connect (custom CRs)

**Business first:** CDC on a **managed broker**. Helm owns Connect, outbox connectors, and secret wiring. The broker itself is not in this chart. Buyer page: [`../../../../../docs/for-business.md`](../../../../../docs/for-business.md). Kit: [`../`](../).

I ran this as a thin parent on a Huawei-class CCE estate. Brokers were managed DMS. What I kept in git is the custom Strimzi CRs and the Vault lookup overrides, not a vendor tarball.

```text
kafka/
  Chart.yaml                 # estate-kafka parent; AKHQ 0.3.1 is a pin only
  values.example.yaml        # kafka.enabled false, one KafkaConnect, outbox list
  templates/
    kafka-connect.yaml
    kafka-connector.yaml
    kafka-user-secret.yaml
    kafka-jaas-secret-override.yaml
    kafka-external-secret.yaml
    akhq-secrets-override.yaml
    _helpers.tpl
```

## Custom CRs vs vendor boundary

| In this folder | Stays out of git |
|----------------|------------------|
| `KafkaConnect` + JMX / log4j ConfigMaps | Strimzi operator chart and CRD tree |
| `KafkaConnector` list (Postgres outbox, `autoRestart`) | In-cluster Kafka / ZooKeeper StatefulSets |
| `ExternalSecret` + Helm `lookup` secret overrides | `charts/akhq` vendor tree |
| Parent `akhq.existingSecrets` overlay | Live `values.yaml`, CA PEMs, connector passwords |

Helm dependency `akhq` 0.3.1 is declared in `Chart.yaml`. Fetch it at install time. Keep the unpacked vendor tree out of git.

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| One `KafkaConnect` | Debezium image talks to an external SASL_SSL bootstrap. Resources sit on `spec.resources` for Strimzi 0.46.0 |
| Outbox connectors | Same `PostgresConnector` + SMT + `autoRestart` shape, one slot per app prefix |
| Vault lookup | Templates read `kafka-vault-credentials` and replace `VAULT_*` placeholders at render |
| JAAS override gated on `kafka.enabled` | Dead path while the broker is external. Kept so the parent still covers an in-cluster lab |

## NOTES

| Vendor | Pin (as used) | What I changed |
|--------|---------------|----------------|
| Strimzi | 0.46.0 | Operator install uses `watchAnyNamespace`. Connect workarounds: `spec.resources`, `KAFKA_CONNECT_CONFIGURATION`, log4j volume under `/mnt/` |
| AKHQ | 0.3.1 | `existingSecrets: kafka-akhq-secrets` plus parent `akhq-secrets-override.yaml` (Vault lookup, not the subchart Secret) |
| Broker | managed DMS | No in-cluster Kafka. Connect and AKHQ point at `kafka.example.com` |

Password rotation needs a Helm render after ExternalSecret sync. `lookup` does not refresh on Secret change alone.

Placeholders follow [`../../../SANITIZE.md`](../../../SANITIZE.md): `10.10.x.x`, `kafka.example.com`, `vault.example.com/kv/...`, `CHANGE_ME`.

**Keywords:** Kafka Connect, Debezium, transactional outbox, Strimzi, AKHQ, External Secrets, Vault, DMS
