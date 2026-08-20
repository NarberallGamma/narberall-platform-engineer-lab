# Ansible kits (code next to the map)

Sanitized trees for [`../`](../) (this catalog). Same habit as Terraform: description and code live under one hub, not a repo-root dump.

| Kit | What hiring sees |
|-----|------------------|
| [`ansible-bootstrap/`](ansible-bootstrap/) | Empty VPS: admin user, SSH keys, Docker CE, optional sshd harden |
| [`ansible-edge/`](ansible-edge/) | Full `xui_docker`: Compose, ACME, panel API, Xray routing, socat, `USR1` |
| [`ansible-payments-idplat/`](ansible-payments-idplat/) | SBP-class identity: AM, IG (YARP), Redis, Postgres; Swarm then Kubernetes |
| [`monitoring-starter/`](monitoring-starter/) | Host metrics: sysstat, vnstat, disk CSV |
| [`ansible-runner/`](ansible-runner/) | Control-node image: ansible-core + jmespath, `--network host` |

Inventories use `*.example.com`. Credentials and `hosts.ini` are gitignored.
