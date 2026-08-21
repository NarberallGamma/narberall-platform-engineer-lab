# Case study: Docker images and Compose stacks

**Context:** CI image library plus host and local Compose; shop, estate, payments-adjacent, and collab estates  
**Timeline:** pins and runners first, then one richest packaging image per mechanic, then host stacks  
**Role:** Platform Engineer (image and Compose owner)

This is **proof** that the path from commit to a running process is an image and a compose or Helm entry, not a laptop build. [Case 11](11-helm-estate.md) is the cluster package after the push. [Case 10](10-ansible-estate.md) is `docker_app` on the hosts. [`iac/ci/`](../iac/ci/) is still the button. I used these Dockerfiles so fifty services shared a parent, and these Compose files so GitLab, Vault, cybersec metrics, and laptop Java stands were `up`, not a console ritual.

Product images exist as **one richest copy per mechanic** under [`iac/docker/images/apps/`](../iac/docker/images/apps/). That is not a hundred-plus identical shop files.

## Challenge

A shop with dozens of backends cannot patch fifty Gradle Dockerfiles by hand. CI needs a Kaniko pin, two runner shapes (kubectl/Helm vs docker-login), and honest Node/JRE retags. Estate sidecars (certs, night-park, CloudEye, EDR coverage) are images with a contract, not a wiki. Host GitLab and Vault are Compose, not Helm. Cybersec Grafana already lived on a VM; that stack had to be published so the Ansible role can copy it. Hunters should parse mechanics, not a dump. The public CI YAML catalog is still thin on purpose: pipelines stay in [`iac/ci/`](../iac/ci/), build context moved here.

## Architecture

See diagram: [`diagrams/case-studies/12-docker-images.md`](../diagrams/case-studies/12-docker-images.md)

```text
1) ci images: kaniko pin, ansible-ee 2.16 + hvac, base-runner-k8s, base-runner-docker,
   jvm-base, liberica-jre, node 20/22 pins, node-e2e-ci, helmfile, maven
2) operators: cert-orchestrator (+ compose), cert-monitoring, hibernate,
   cloud-metrics (Dockerfile only), cloud-status, static-nginx, edr-coverage
3) apps: one Java combined, one Java split-runtime, Next vs nginx SPA,
   two e2e styles, vitest (shared .npmrc), newman, packaging and service images
4) compose: sec-stack (also extras/sec-stack/stack/), hsm-adapter,
   gitlab-omnibus DEV/PROD, vault DEV/PROD, dev-deps, java-local-dev, shop-extras,
   php-dev, app-adjacent compose, collab (Atlassian / Nextcloud / n8n / OCR / KRaft)
5) after push: registry → Helm / Argo or compose up
```

Honest scope: one mechanic per image, not a hundred-plus shop clones. CloudEye Go `src/` is not in git. App trees, JARs, Postman collections, and DLLs stay out. CI YAML here is a couple of kit files, not a second catalog.

## What shipped (image library)

- Kaniko retag and ansible-ee (Vault collections). Lab ansible-runner stays the other variant
- Two base runners: Kubernetes (kubectl/Helm/`regcred`) and Docker-login (client 26.1.1)
- JVM 11 pin, Liberica 21 + CA/tzdata, Node 20/22 pins, Node 22 + Chromium, helmfile, Maven + docker CLI
- Cert orchestrator (DNS-01, k8s secrets, SSH nginx) with compose next to the image
- Hibernate night-park, SSL watcher, CloudEye Dockerfile (src out), cloud-status exporter, static nginx, EDR coverage (`vendor-edr.py`)
- Combined Gradle+Temurin image and Liberica split-runtime pair
- Next standalone + one `.npmrc`; nginx SPA + envsubst; ENV e2e vs env-file e2e; vitest shares the npmrc; Newman
- Python service, ships-api, ships-bridge. Packaging (NiFi, Keycloak, Superset, JSM, python-agent). PHP family, Poetry set, Dashy, Go/Wine, Octane, RoadRunner, private npm, ovpn-admin, nginx-limit-upstream, libvirt-guest

## What shipped (Compose)

- Host sec-stack: eight services (VictoriaMetrics, vmagent, vmalert, Alertmanager, Grafana, blackbox, PAN-OS, EDR). Published under [`iac/docker/compose/sec-stack/`](../iac/docker/compose/sec-stack/) and [`iac/ansible/reference/ansible-llm-collab/extras/sec-stack/stack/`](../iac/ansible/reference/ansible-llm-collab/extras/sec-stack/stack/)
- HSM adapter nginx vhost
- GitLab Omnibus DEV + PROD and Vault + nginx DEV + PROD
- Local Java deps (Jaeger, Kafka, MinIO, Postgres, Keycloak, Locust)
- Local JVM stands including host-DB as `shop-rate`
- Shop extras: NiFi, docs portal, fluent-bit sidecar, static site build
- PHP DEV compose and app-adjacent stands (ovpn-admin, Octane, RoadRunner, AMQP, Wine bridge, Poetry admin)
- Collab host stacks: Jira, Confluence, JSM, Nextcloud (fpm+clamav), n8n+Postgres, Postfix, edge nginx, Content Capture 14.12, Kafka KRaft + Vault cert pull. Ansible ACL / n8n JSON stay in [`iac/ansible/reference/ansible-llm-collab/`](../iac/ansible/reference/ansible-llm-collab/)

## Results

- A new service reuses a parent image. Reviewers parse one Dockerfile per class
- Host GitLab, Vault, and cybersec metrics are `compose up` with example env files
- Helm remains the cluster package. Compose remains the VM and laptop path
- Night-park, CloudEye, and EDR coverage stay complementary to Ansible and the Helm overlay
- CI catalog stays the YAML map. This case does not claim a full private pipeline dump

## Stack

Docker, Compose, Kaniko, GitLab CI, Jenkins, Harbor-class registry, Helm, Argo CD, Ansible, Gradle, Liberica, Temurin, Node, Playwright, Newman, PHP, Poetry, Keycloak, NiFi, Superset, Vault, GitLab Omnibus, VictoriaMetrics, Grafana, Alertmanager, CloudEye, EDR

## Links

- Docker hub: [`iac/docker/`](../iac/docker/)
- Images: [`iac/docker/images/`](../iac/docker/images/)
- Compose: [`iac/docker/compose/`](../iac/docker/compose/)
- Collab compose: [`iac/docker/compose/collab/`](../iac/docker/compose/collab/)
- sec-stack (hunter): [`iac/docker/compose/sec-stack/`](../iac/docker/compose/sec-stack/)
- sec-stack (Ansible copy): [`iac/ansible/reference/ansible-llm-collab/extras/sec-stack/stack/`](../iac/ansible/reference/ansible-llm-collab/extras/sec-stack/stack/)
- CI catalog: [`iac/ci/`](../iac/ci/)
- Helm after the push: [`iac/helm/`](../iac/helm/), [case 11](11-helm-estate.md)
- Host Ansible: [`iac/ansible/reference/ansible-estate/`](../iac/ansible/reference/ansible-estate/), [case 10](10-ansible-estate.md)
- SRE layers: [`../docs/sre/layers.md`](../docs/sre/layers.md), [`../architecture/05-sre.md`](../architecture/05-sre.md)
- Sanitize: [`iac/docker/SANITIZE.md`](../iac/docker/SANITIZE.md)
