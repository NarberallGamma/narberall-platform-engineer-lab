# Compose

**Business first:** a host or a laptop stand is **`compose up`**, not a cluster envelope. Buyer page: [`../../../docs/for-business.md`](../../../docs/for-business.md). Case: [`../../../case-studies/12-docker-images.md`](../../../case-studies/12-docker-images.md). Hub: [`../`](../).

I publish living Compose here. Images those files pull (or build) live under [`../images/`](../images/). The Ansible role that copies the cybersec stack onto a VM reads [`../../ansible/reference/ansible-llm-collab/extras/sec-stack/stack/`](../../ansible/reference/ansible-llm-collab/extras/sec-stack/stack/) (`src: playbook_dir/../../stack/`). That tree is the same compose as [`sec-stack/`](sec-stack/).

Cluster mesh, CDC, and Argo stay in [`../../helm/`](../../helm/). Do not merge host Grafana into the CCE overlay.

```text
compose/
  sec-stack/                 # 8-service host metrics (published)
  hsm-adapter/
  gitlab-omnibus/
  vault/
  dev-deps/
    jaeger/ kafka/ minio/ postgres/ keycloak/ locust/
  java-local-dev/
    java-local-stack/ java-app-stack/ java-host-db/
    java-kraft-topics/ outbox-demo/ keycloak-spi/
  shop-extras/               # nifi, docs-portal, fluent-bit-sidecar, static-site-build
  php-dev/                   # shop / API / OMS / broker / vue / e2e
  ovpn-admin/ php-octane/ php-roadrunner/ php-amqp/ go-wine-bridge/ poetry-admin/
  collab/                    # Jira, wiki, JSM, Nextcloud, n8n, postfix, edge, OCR, Kafka
```

App-adjacent Compose sits in sibling folders next to those images. Cert-orchestrator compose sits next to its image: [`../images/operators/cert-orchestrator/`](../images/operators/cert-orchestrator/).

## Who this page is for

| Reader | What to take | Then open |
|--------|----------------|-----------|
| Hiring lead | Host GitLab, Vault, and cybersec metrics are compose, not Helm. Local Java deps are six small files. | Table below, [case 12](../../../case-studies/12-docker-images.md) |
| Engineer | `compose up` from the kit folder. Secrets are `.env.example` only. | Kit table |
| Founder / PM | Idle laptop stands are not a CCE bill. Host Grafana stays on a VM. | [`sec-stack/`](sec-stack/), [`../../../docs/sre/layers.md`](../../../docs/sre/layers.md) |

## On disk

Stacks that already have a compose file when this page was written:

| Folder | What is there |
|--------|----------------|
| [`sec-stack/`](sec-stack/) | `docker-compose.yml` (8 services), Grafana dashboards, vmalert rules, PAN-OS exporter Dockerfile, `.env.example`. Same tree under extras `stack/` |
| [`hsm-adapter/`](hsm-adapter/) | `docker-compose.yaml` + `nginx.conf` |
| [`gitlab-omnibus/`](gitlab-omnibus/) | `docker-compose.dev.yml`, `docker-compose.prod.yml`, `.env.example`, two site confs |
| [`vault/`](vault/) | `docker-compose.dev.yml`, `docker-compose.prod.yml`. `config/` / `ssl/` / `data/` stay off git |
| [`dev-deps/`](dev-deps/) | `jaeger`, `kafka`, `minio`, `postgres`, `keycloak`, `locust` |
| [`java-local-dev/`](java-local-dev/) | local-stack, app-stack, host-db (`shop-rate`), kraft-topics, outbox-demo, keycloak-spi |
| [`shop-extras/`](shop-extras/) | `nifi`, `docs-portal`, `fluent-bit-sidecar`, `static-site-build` |
| [`php-dev/`](php-dev/) | `shop-app`, `shop-app-m1`, `shop-app-vue`, `shop-app-e2e`, dashboard, API, sticker, OMS, OMS-dev, broker |
| [`ovpn-admin/`](ovpn-admin/) | `docker-compose.yaml` + templates |
| [`php-octane/`](php-octane/) | `docker-compose.yml` |
| [`php-roadrunner/`](php-roadrunner/) | `docker-compose.yml` |
| [`php-amqp/`](php-amqp/) | `docker-compose.yml` |
| [`go-wine-bridge/`](go-wine-bridge/) | `docker-compose.yaml` |
| [`poetry-admin/`](poetry-admin/) | `docker-compose.yaml` |
| [`collab/`](collab/) | Jira, wiki, JSM, Nextcloud, n8n, postfix, edge-proxy, content-capture, kafka-broker |

## Stacks

| Slice | What it is | Why it exists (buyer) | What an engineer parses |
|-------|------------|------------------------|-------------------------|
| [`sec-stack/`](sec-stack/) | Host VictoriaMetrics + Grafana + Alertmanager + vmalert + blackbox + PAN-OS + EDR | Cybersec on-call already had a VM. The stack is published | 8 services. Ansible copy: [`../../ansible/reference/ansible-llm-collab/extras/sec-stack/stack/`](../../ansible/reference/ansible-llm-collab/extras/sec-stack/stack/) |
| [`hsm-adapter/`](hsm-adapter/) | nginx TLS vhost in front of an HSM adapter | Signing is a published name, not a raw port | Compose + `nginx.conf` |
| [`gitlab-omnibus/`](gitlab-omnibus/) | GitLab EE Omnibus DEV + PROD | The product install is two files and site confs | `gitlab/gitlab-ee:19.0.1-ee.0`, example hostnames |
| [`vault/`](vault/) | Vault + nginx, DEV + PROD | Host secrets plane. Not the Kafka cert sidecar | Compose only in git |
| [`dev-deps/jaeger/`](dev-deps/jaeger/) | Local traces | Laptop stand, not the Helm data-plane kit | Compose |
| [`dev-deps/kafka/`](dev-deps/kafka/) | Local broker | Contrast with managed Kafka on CCE | Compose |
| [`dev-deps/minio/`](dev-deps/minio/) | Local object store | Contrast with in-cluster MinIO addon | Compose |
| [`dev-deps/postgres/`](dev-deps/postgres/) | Local Postgres | Contrast with managed RDS | Compose |
| [`dev-deps/keycloak/`](dev-deps/keycloak/) | Local SSO | Contrast with the Helm Keycloak overlay | Compose |
| [`dev-deps/locust/`](dev-deps/locust/) | Load generator | A file and an env example | `locustfile.py` |
| [`java-local-dev/java-local-stack/`](java-local-dev/java-local-stack/) | Full local JVM stand | One compose for the laptop | `init.sql` |
| [`java-local-dev/java-app-stack/`](java-local-dev/java-app-stack/) | App-only stand | Thinner than local-stack | Compose |
| [`java-local-dev/java-host-db/`](java-local-dev/java-host-db/) | App against host Postgres | `shop-rate` / `shop_rate` (renamed) | `host.docker.internal` |
| [`java-local-dev/java-kraft-topics/`](java-local-dev/java-kraft-topics/) | Kafka Kraft + topics | Topic create is compose, not a ticket | Compose |
| [`java-local-dev/outbox-demo/`](java-local-dev/outbox-demo/) | Outbox CDC demo | Same idea as Helm Connect, on a laptop | `init.sql` |
| [`java-local-dev/keycloak-spi/`](java-local-dev/keycloak-spi/) | Keycloak SPI stand | Local SPI, not the estate overlay | Compose |
| [`shop-extras/nifi/`](shop-extras/nifi/) | Local NiFi | Shop-class flow, not the Helm data-plane kit | Compose |
| [`shop-extras/docs-portal/`](shop-extras/docs-portal/) | Docs portal | `.env.example` + compose | Compose |
| [`shop-extras/fluent-bit-sidecar/`](shop-extras/fluent-bit-sidecar/) | fluent-bit next to an app | Sidecar log ship, not OpenObserve | Compose |
| [`shop-extras/static-site-build/`](shop-extras/static-site-build/) | Static site build stand | Build, not the Ubuntu nginx image | Compose |
| [`php-dev/`](php-dev/) | PHP DEV family | x86, M1, vue, e2e, dashboard, API, sticker, OMS, broker | One file per stand |
| [`ovpn-admin/`](ovpn-admin/) | OpenVPN admin compose | Next to [`../images/apps/ovpn-admin/`](../images/apps/ovpn-admin/) | `docker-compose.yaml` |
| [`php-octane/`](php-octane/) | Swoole / Octane compose | Contrast with RoadRunner | `docker-compose.yml` |
| [`php-roadrunner/`](php-roadrunner/) | RoadRunner compose | Contrast with Octane | `docker-compose.yml` |
| [`php-amqp/`](php-amqp/) | PHP AMQP compose | Broker stand next to PHP | `docker-compose.yml` |
| [`go-wine-bridge/`](go-wine-bridge/) | Go + Wine compose | Next to the three Dockerfiles | `docker-compose.yaml` |
| [`poetry-admin/`](poetry-admin/) | Poetry admin compose | Next to [`../images/apps/poetry-admin/`](../images/apps/poetry-admin/) | `docker-compose.yaml` |
| [`collab/`](collab/) | Atlassian / Nextcloud / n8n / OCR / KRaft | Collaboration is a host compose | Living snapshots. Ansible half: [`../../ansible/reference/ansible-llm-collab/`](../../ansible/reference/ansible-llm-collab/) |

## What this folder is not

- Not a cluster package. Mesh, Argo, and in-cluster Grafana live under [`../../helm/`](../../helm/)
- Not a dump of every compose file from a shop or collab estate. One richest file per job. Near-duplicates and cartesian products stay private
- Not application source, JAR, or vendor binaries. Compose is the stand. The product tree is not in this lab
- Not live secrets. Unseal keys, root passwords, PEM, and valued `.env` stay out of git

**Keywords:** Compose, GitLab Omnibus, Vault, VictoriaMetrics, Grafana, Alertmanager, HSM, Kafka, MinIO, Keycloak, NiFi, Locust, PHP, Atlassian, Nextcloud
