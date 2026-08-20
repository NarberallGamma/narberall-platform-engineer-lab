# Application-estate Ansible (Kafka, EDR, Prometheus, Postgres)

**Business first:** brokers, scrape, and Postgres users have a lifecycle in git so a stuck Kafka or a leftover DB account is not a tribal fix.

I used this tree after the hosts were already inventory. The job is **application-estate Ansible**: Kafka mTLS, EDR agent roll-out, cron harden, a Prometheus stack, node_exporter, and Postgres user lifecycle. Not host bootstrap. Not a payments autodeploy.

Hunter map: [`../`](../). Estate sibling: [`../ansible-estate/`](../ansible-estate/). Host metrics starter: [`../monitoring-starter/`](../monitoring-starter/). Experience: [`../../../../docs/experience.md`](../../../../docs/experience.md).

Brand, live IPs, people keys, EDR packages, and Kafka PEMs are stripped. Role tasks, Jinja, scrape jobs, and Vault lookup graphs stay almost intact so a reviewer can parse a real estate, not a three-task demo.

```text
ansible-app-platform/
  admin-users.yml         # named admins + authorized_keys
  hardering.yml           # cron mode harden (filename keeps the original typo)
  edr.yml                 # edr-vendor agent .deb + /etc/hosts pin
  kafka.yml               # three Kafka clusters, Vault-sourced EIP cert
  monitoring-deploy.yml   # Prometheus + VictoriaMetrics compose
  node_exporter.yml
  db-create.yaml          # create empty DBs
  db-dev.yaml db-preprod.yml db-prod.yaml db-loadtesting.yaml
  db.convert.py db.yml.sh kafka-mtls-cert.sh s3-create.sh
  inventory.ini.example
  roles/
    admin-users db db-pass db-readonly-users db-v1
    edr hardering_cron kafka monitoring_deploy node_exporter
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| `kafka` + `kafka-mtls-cert.sh` | KRaft broker with PEM mTLS, SCRAM on the client listener, Vault sidecar that refreshes the EIP cert, cron restart when the PEM changes. |
| `db` / `db-pass` / `db-readonly-users` / `db-v1` | Vault-backed Postgres user lifecycle: owner NOLOGIN roles, TUZ passwords, SET ROLE, default privileges, readonly SELECT. Full stand lists, not one demo DB. |
| `monitoring_deploy` | Prometheus scrape of the estate plus Kubernetes SD and blackbox probes. Compose stack with VictoriaMetrics. I query that stack through the Prom / VM HTTP APIs the same way I edit Grafana views in the Helm overlay ([`../../../helm/reference/helm-estate-cluster/monitoring/`](../../../helm/reference/helm-estate-cluster/monitoring/), [`../../../../architecture/05-sre.md`](../../../../architecture/05-sre.md), [`../../../../docs/sre/`](../../../../docs/sre/)). |
| `node_exporter` | CentOS rpm path and Debian tarball path, systemd / upstart / sysv, textfile collector scripts. |
| `edr` | Concept roll-out of a vendor agent `.deb` with `/etc/hosts` pin. The package stays local. |
| `hardering.yml` | Original filename spelling. Role walks cron.d / daily / hourly / monthly / weekly and sets mode `0744`. |

```bash
cp inventory.ini.example inventory.ini
# place roles/edr/files/edr-agent.deb on the control node (not in git)
# place Kafka PEMs next to roles/kafka/templates/*.pem.example if a lab run needs real files
ansible-galaxy collection install -r requirements.yml
ansible-playbook -i inventory.ini node_exporter.yml
ansible-playbook -i inventory.ini kafka.yml --tags kafka-preprod
ansible-playbook -i inventory.ini db-dev.yaml
```

## Playbooks

| Playbook | Scope |
|----------|-------|
| `admin-users.yml` | `admin` / `admin01` on `all`, then extra plays for monitoring, ELK, appsec |
| `hardering.yml` | Cron directory modes on `all` (typo in the filename is intentional) |
| `edr.yml` | EDR agent on `all`, package `edr-agent.deb` |
| `kafka.yml` | IFT, preprod, and prod Kafka trios (`kafka-preprod` / `kafka-prod` tags) |
| `monitoring-deploy.yml` | Prometheus stack on `monitoring-dev` |
| `node_exporter.yml` | node_exporter on `all` |
| `db-create.yaml` | Create listed Postgres databases |
| `db-dev.yaml` / `db-preprod.yml` / `db-prod.yaml` / `db-loadtesting.yaml` | Per-stand user and DB lifecycle via Vault |

## Roles

| Role | Job |
|------|-----|
| `admin-users` | Wheel/sudo users, `authorized_key` from `*.pub.example`, colored bash profile |
| `hardering_cron` | Find cron files and set mode `0744` |
| `edr` | `/etc/hosts` pin, copy local `.deb`, `apt` install with edr-vendor env |
| `kafka` | Dirs, server/client properties, example PEMs, compose, log-clean cron |
| `monitoring_deploy` | Prometheus config + VictoriaMetrics compose up. Query API same habit as the Helm Grafana overlay |
| `node_exporter` | Exporter install for CentOS and Debian |
| `db-pass` | Read or generate Vault passwords (`hvac`) |
| `db` | Owner roles, DBs, TUZ and human users, grants, SET ROLE |
| `db-readonly-users` | CONNECT / USAGE / SELECT and default privileges |
| `db-v1` | Same lifecycle plus reassign of existing objects |

## Inventory contract

- Copy `inventory.ini.example` to `inventory.ini` (gitignored)
- Internal addresses use `10.10.x.x`; published EIPs use `203.0.113.x`
- Kafka `ehost` values are `*.example.com`
- Vault tokens come from `VAULT_ADDR_DEV` / `VAULT_TOKEN_DEV` and the prod pair
- EDR package: `roles/edr/files/edr-agent.deb` (see that directory README)
- Kafka TLS: `roles/kafka/templates/{0,1,2,eip}.pem.example` and `ca.crt.example`

## Keywords

Ansible, Kafka, mTLS, KRaft, Vault, EDR, Prometheus, VictoriaMetrics, Grafana, node_exporter, PostgreSQL, HashiCorp Vault, Docker Compose
