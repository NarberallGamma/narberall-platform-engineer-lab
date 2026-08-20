# ansible-edge

Full **xui_docker** role (same task graph as the private playbook): host dirs, UFW, ACME layout, Compose pin, panel API bootstrap, Xray inbound/clients/outbounds, extra inbounds, per-inbound routing, scheduled restart, SSH failover.

Practice: [`../../../../practice/home-lab/edge-platform.md`](../../../../practice/home-lab/edge-platform.md). IaC hub: [`../../`](../../).

This is **not** a click-ops dump. Credentials, real IPs, and dest/SNI values stay in gitignored `artifacts/` and private group_vars. Published group_vars use `*.example.com` placeholders.

## Layout

```text
ansible-edge/
  playbooks/xui_main.yml      # hosts: xui_main
  playbooks/xui_proxy.yml     # hosts: xui_proxy (jump)
  inventories/hosts.ini.example
  inventories/group_vars/xui_main.yml
  inventories/group_vars/xui_proxy.yml
  roles/xui_docker/           # full role (tasks + templates + defaults)
  scripts/run_edge.sh
```

```bash
cp inventories/hosts.ini.example inventories/hosts.ini
./scripts/run_edge.sh --main --tags compose
./scripts/run_edge.sh --jump --tags routing -e xui_routing_outbound_tag=outbound-vless-eu-1
```

## Role graph (`roles/xui_docker/tasks/main.yml`)

| Tag | Tasks |
|-----|--------|
| `preflight` | Derived facts |
| `dirs` | App / cert / artifact dirs |
| `ufw` | Default incoming deny; SSH / 80 / 443 / panel |
| `ssl` | acme.sh IP cert on the host (HTTP-01) |
| `compose` | Pinned image, `.env` 0600, compose up |
| `scheduled_restart` | systemd timer → `docker kill --signal=USR1` or container restart |
| `panel` | First-init, token, `webBasePath`, `panel-access.json` artifact |
| `xray` / `autoconfigure` | Keys, inbound create/sync, clients registry, extra inbounds, inbound-summary |
| `routing` | Jump: outbounds from **main artifacts**, tag switch (`xui_routing_outbound_tag`) |
| `profile` | Rendered Xray profile YAML (operator notes, not dest recipes) |
| `ssh_tunnel` | socat unit + `nologin` users + sshd `Match Group` |

Idempotency: client UUID registry, extra-inbound password registry, `inbound-summary.json` consumed by the proxy play so jump outbounds are generated from mains, not typed twice.

## What is not in git

- Panel passwords, API cookies, client UUID files
- Real inventory IPs and hostnames
- Production dest/SNI lists
- `artifacts/` (gitignore)

Related: [`../ansible-bootstrap/`](../ansible-bootstrap/), [`../monitoring-starter/`](../monitoring-starter/), [`../ansible-runner/`](../ansible-runner/), [`../../../../practice/home-lab/reference/apps/ssh-tunnel-android/`](../../../../practice/home-lab/reference/apps/ssh-tunnel-android/).

## Keywords

Ansible, Docker Compose, GitOps, ACME, UFW, systemd, 3X-UI, Xray, panel API, jump host, SSH, socat, inventory tags
