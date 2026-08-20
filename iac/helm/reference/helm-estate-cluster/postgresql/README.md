# Zalando Postgres (DEMO)

I used this path on a **lab / DEMO** cluster. Production Postgres on the estate was managed RDS. This kit is the in-cluster operator story: a Zalando `postgresql` CR plus a small operator ConfigMap MVP.

I did not copy DEMO Bitnami Kafka. Brokers for the estate live in the Kafka slice (Connect on an external broker).

```text
postgresql/
  Chart.yaml
  values.yaml
  templates/postgres.yaml
  templates/_helpers.tpl
  operator/
    Chart.yaml
    values.yaml
    templates/configmap.yaml
    templates/_helpers.tpl
    NOTES.md
  README.md
```

CR facts I kept: 2 instances, PgBouncer pooler, `wal_level: logical` for CDC, twelve lab databases, user `lab_user` with `REPLICATION`. External pooler Service stays off.

Operator is small, so I copied the MVP instead of NOTES-only. See `operator/NOTES.md`.

**Keywords:** Zalando, Spilo, Patroni, PgBouncer, logical replication
