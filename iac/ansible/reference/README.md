# Ansible kits (code next to the map)

Sanitized trees for [`../`](../) (this catalog). Same habit as Terraform: description and code live under one hub, not a repo-root dump.

Each kit README states **what** the tree is, **why** a buyer pays, and **how** an engineer runs it. The hub table on [`../`](../) is the audience map. LLM + collab (private API, Nextcloud, n8n, Kafka, CIS) is the largest tree: [`ansible-llm-collab/`](ansible-llm-collab/).

| Kit | What hiring sees |
|-----|------------------|
| [`ansible-bootstrap/`](ansible-bootstrap/) | Empty VPS: admin user, SSH keys, Docker CE, optional sshd harden |
| [`ansible-edge/`](ansible-edge/) | Full `xui_docker`: Compose, ACME, panel API, Xray routing, socat, `USR1` |
| [`ansible-payments-idplat/`](ansible-payments-idplat/) | SBP-class identity: AM, IG (YARP), Redis, Postgres; Swarm then Kubernetes |
| [`ansible-llm-collab/`](ansible-llm-collab/) | GPU/LLM, Nextcloud, Kafka, CIS Ubuntu 24, n8n |
| [`ansible-estate/`](ansible-estate/) | Huawei-class estate: docker_app, Vault, hibernate, DB users |
| [`ansible-app-platform/`](ansible-app-platform/) | Kafka mTLS, EDR, cron harden, Prometheus, Postgres users |
| [`ansible-kb-linux/`](ansible-kb-linux/) | PostgreSQL / Percona, NTP, Ubuntu host audit |
| [`ansible-backup-borg/`](ansible-backup-borg/) | Borg user + dump scripts |
| [`ansible-aws-hosts/`](ansible-aws-hosts/) | AWS bastion / DB / disks / users / backup |
| [`monitoring-starter/`](monitoring-starter/) | Host metrics: sysstat, vnstat, disk CSV |
| [`ansible-runner/`](ansible-runner/) | Control-node image: ansible-core + jmespath, `--network host` |

Inventories use `*.example.com`. Credentials and live `hosts.ini` are gitignored. Checklist: [`../SANITIZE.md`](../SANITIZE.md).
