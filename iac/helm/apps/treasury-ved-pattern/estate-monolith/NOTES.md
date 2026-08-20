# Vendor pins (not vendored)

The source stand shipped six tarballs under `charts/`. Those files and any unpacked trees stay out of git. Run `helm dependency build` against the pins below when a local render needs the subcharts.

| Chart | Version | Repository (as used) | Condition / alias | In git |
|-------|---------|----------------------|-------------------|--------|
| kafka (Bitnami) | 12.17.5 | `https://charts.bitnami.com/bitnami` | `kafka.enabled` | pin only |
| akhq | 0.3.1 | `https://akhq.io/` | `akhq.enabled` | pin only |
| keycloak (codecentric) | 17.0.2 | `https://codecentric.github.io/helm-charts` | `keycloak.enabled` | pin only |
| vault (HashiCorp) | 0.28.1 | `https://helm.releases.hashicorp.com/` | `vault.enabled` | pin only |
| base-chart | 0.2.1 | `file://../_libs/base-chart` | five app aliases | shared lib, not a second copy |
| front-base | 0.1.1 | `file://../_libs/front-base` | `operator-ui` | shared lib, not a second copy |

Source tarball names that must not be copied:

- `akhq-0.3.1.tgz`
- `kafka-12.17.5.tgz`
- `keycloak-17.0.2.tgz`
- `vault-0.28.1.tgz`
- `base-chart-0.2.1.tgz`
- `front-base-0.1.1.tgz`

The source Chart.yaml listed about eighteen `base-chart` aliases (ledger, chain adapters, OTP, web, contract, report, AML, notification, rates, audit, auth, KYC, and similar). This SAMPLE keeps five aliases that the overlay Services actually select, plus `operator-ui`. The rest of the product umbrellas live in sibling folders under `treasury-ved-pattern/`.

Strimzi operator and Zalando Postgres operator stay cluster installs. This chart only emits CRs.

Related kits:

- Estate Kafka Connect on an external broker: `../../../reference/helm-estate-cluster/kafka/`
- Zalando Postgres DEMO: `../../../reference/helm-estate-cluster/postgresql/`
- Keycloak overlay: `../../treasury-keycloak/`
