# Case study: Huawei-class estate Ansible

**Context:** Huawei Cloud class compute already in Terraform; hosts still need an Ansible runbook  
**Timeline:** prepare, docker-app family, Vault, DB users, scheduled hibernate  
**Role:** Platform Engineer (Ansible owner for the estate)

This is **proof** that the Huawei-class story is not only a compute catalog. [Case 07](07-huawei-compute-catalog.md) is the Terraform root (CCE, RDS, purpose ECS). This case is what runs **on those hosts** after apply: inventory, roles, and playbooks that install Docker apps, wire Vault, open a cert orchestrator path, and park idle compute.

Not a second payments-identity tree. That proof is [case 08](08-payments-swarm-autodeploy.md).

## Challenge

The estate is not one compose file. Edge load-balancer, HSM adapter, CryptoPro, GitLab nginx, treasury policy gateway, and a cloud hibernate operator each have their own templates and group_vars, but they share one `docker_app` engine. Vault deploy/init/secrets is a separate path. Postgres users and schema migrate must not sit next to live passwords in git. Preprod is the same tree pointed at another inventory, not a fork.

## Architecture

See diagram: [`diagrams/case-studies/10-ansible-estate.md`](../diagrams/case-studies/10-ansible-estate.md)

```text
1) inventories/prod|preprod|demo with the same group names
2) prepare_servers / prepare_vps_cluster / bootstrap users
3) docker_app engine + per-app templates (edge LB, HSM, CryptoPro, GitLab, certs, gateway, hibernate)
4) node-exporter (`:9100`); scraped by `ansible-app-platform` `monitoring_deploy` (Prom → VictoriaMetrics); the Helm overlay ([case 11](11-helm-estate.md)) alerts on those host metrics
5) Vault roles (docker, load-balancer, secrets)
6) estate_databases: rw/ro users, drop, schema migrate
```

Honest scope: network and CCE stay in Terraform. This tree assumes SSH reachability and an inventory. `docker_app` consumes published operator images: [`hibernate`](../iac/docker/images/operators/hibernate/), [`cert-orchestrator`](../iac/docker/images/operators/cert-orchestrator/) (compose sits next to that image), and [`cert-monitoring`](../iac/docker/images/operators/cert-monitoring/). The image library case is [12](12-docker-images.md). Host Prom to VictoriaMetrics, blackbox, and Kubernetes SD live in [`ansible-app-platform`](../iac/ansible/reference/ansible-app-platform/), not in this docker_app tree. Host Grafana / vmalert / Alertmanager live in [`sec-stack`](../iac/ansible/reference/ansible-llm-collab/extras/sec-stack/). sar / vnstat before a full scrape estate: [`monitoring-starter`](../iac/ansible/reference/monitoring-starter/).

## What shipped

- Shared `docker_app` role plus one playbook per product. Images those slugs consume: [`../iac/docker/images/operators/`](../iac/docker/images/operators/)
- Night-park hibernate operator as Ansible, not a wiki reminder. Image: [`../iac/docker/images/operators/hibernate/`](../iac/docker/images/operators/hibernate/)
- Vault deploy/init/secrets playbooks
- DB user lifecycle next to the app estate: Flyway/DDL owner vs app DML, RO (audit/BI), RW (tools), drop without REASSIGN, `REPLICATION` for Debezium
- Public lab: brands and live certs stripped; role logic kept

## Results

- **Hours per host, not a rebuild:** `--limit` + shared `docker_app`. Preprod is the same roles, other inventory
- **Night park in git:** idle non-prod stops paying 24/7 ECS/CCE. First cuts in days ([`../architecture/02-finops-night-park.md`](../architecture/02-finops-night-park.md))
- **Ship:** Vault, cert path, and RDS users (Flyway vs app DML, RO/RW) are playbooks. Product wait on a host change drops to a limit
- Host `:9100` is the scrape half of [case 11](11-helm-estate.md). Prom → VictoriaMetrics and host Grafana live in the sibling kits below

## Stack

Ansible, Docker, nginx, Vault, CryptoPro, HSM, GitLab, Prometheus, VictoriaMetrics, node-exporter, PostgreSQL, Flyway, Huawei-class hosts

## Links

- Sanitized code: [`iac/ansible/reference/ansible-estate/`](../iac/ansible/reference/ansible-estate/)
- Operator images `docker_app` consumes: [`iac/docker/images/operators/`](../iac/docker/images/operators/)
- Image library: [case 12](12-docker-images.md)
- Ansible hub: [`iac/ansible/`](../iac/ansible/)
- Host Prom / VM / blackbox: [`iac/ansible/reference/ansible-app-platform/`](../iac/ansible/reference/ansible-app-platform/)
- Host Grafana / vmalert: [`iac/ansible/reference/ansible-llm-collab/extras/sec-stack/`](../iac/ansible/reference/ansible-llm-collab/extras/sec-stack/)
- Host sar before Prom: [`iac/ansible/reference/monitoring-starter/`](../iac/ansible/reference/monitoring-starter/)
- In-cluster overlay: [`iac/helm/reference/helm-estate-cluster/monitoring/`](../iac/helm/reference/helm-estate-cluster/monitoring/)
- SRE / product APIs: [`../architecture/05-sre.md`](../architecture/05-sre.md)
- Terraform catalog: [`07-huawei-compute-catalog.md`](07-huawei-compute-catalog.md)
- Night park: [`../architecture/02-finops-night-park.md`](../architecture/02-finops-night-park.md)
- Host baseline (separate): [`iac/ansible/reference/ansible-bootstrap/`](../iac/ansible/reference/ansible-bootstrap/)
