# Helm KB examples

**Business first:** small teaching charts I actually applied (authz, Redis operator, backup). Not 50 generic stacks. Hub: [`../../`](../../).

```text
helm-kb-examples/
  d8-authz/
  redis-operator/
  borg/
  restic/
```

None of the four trees has `Chart.yaml` (werf-raw `.helm/`). Generic nginx/php/mysql/postgres/kafka_zk examples stay out. Production Kafka is [`../helm-estate-cluster/kafka/`](../helm-estate-cluster/kafka/). Host Borg Ansible kit: [`../../../ansible/reference/ansible-backup-borg/`](../../../ansible/reference/ansible-backup-borg/).

**Keywords:** Deckhouse, authorization, Redis operator, Borg, restic, werf
