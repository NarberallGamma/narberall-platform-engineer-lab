# NOTES

This is an MVP ConfigMap overlay, not the full Zalando operator Helm tree. I used it on a DEMO stand: Helm install, then CI overwrote `postgres-operator` so the operator picked up this config.

`spilo_privileged` and `SYS_ADMIN` are DEMO facts. Production data on that estate was RDS, not this operator.

CRDs and the operator Deployment come from the upstream Zalando chart. This folder only ships the ConfigMap values.
