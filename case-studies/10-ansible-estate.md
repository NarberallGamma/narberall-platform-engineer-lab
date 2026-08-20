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
4) node-exporter
5) Vault roles (docker, load-balancer, secrets)
6) estate_databases: rw/ro users, drop, schema migrate
```

Honest scope: network and CCE stay in Terraform. This tree assumes SSH reachability and an inventory.

## What shipped

- Shared `docker_app` role plus one playbook per product
- Night-park hibernate operator as Ansible, not a wiki reminder
- Vault deploy/init/secrets playbooks
- DB user lifecycle next to the app estate: Flyway/DDL owner vs app DML, RO (audit/BI), RW (tools), drop without REASSIGN, `REPLICATION` for Debezium
- Public lab: brands and live certs stripped; role logic kept

## Results

- A host change is a playbook limit, not a rebuild
- Preprod reuses the same roles
- Reviewers see a real docker-app graph, not a single nginx demo

## Stack

Ansible, Docker, nginx, Vault, CryptoPro, HSM, GitLab, Prometheus node-exporter, PostgreSQL, Flyway, Huawei-class hosts

## Links

- Sanitized code: [`iac/ansible/reference/ansible-estate/`](../iac/ansible/reference/ansible-estate/)
- Ansible hub: [`iac/ansible/`](../iac/ansible/)
- Terraform catalog: [`07-huawei-compute-catalog.md`](07-huawei-compute-catalog.md)
- Night park: [`../architecture/02-finops-night-park.md`](../architecture/02-finops-night-park.md)
- Host baseline (separate): [`iac/ansible/reference/ansible-bootstrap/`](../iac/ansible/reference/ansible-bootstrap/)
