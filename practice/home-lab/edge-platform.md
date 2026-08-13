# Edge platform (Ansible + Xray)

**Role:** I built a **from-scratch Ansible** delivery for a multi-region access platform: host bootstrap, Dockerized panel, API-driven proxy core, TLS, firewall, metrics, scheduled restart, SSH failover.

This is GitOps for a small fleet. Client names, IPs, panel URLs, and credentials stay private. Published here is the **engineering shape**.

## Why it exists

Click-ops on a panel does not scale across regions or survive rebuilds. I wanted:

- empty VPS → hardened user, Docker, firewall
- panel + core as Compose
- inbounds, clients, outbounds, routing applied **idempotently via API**
- artifacts on the operator machine (gitignore), not in git
- a second path if the TLS inbound is blocked: restricted SSH + local port-forward

## Topology (generic)

```text
clients  →  regional jump (optional)  →  EU mains
                │
                └── SSH failover: jump socat → main :443
```

- **mains:** terminate the core protocol, issue client links
- **jump / proxy:** extra inbounds, outbound list, routing tag switch between mains without rebuilding inbounds
- **operator:** custom `ansible-runner` image + wrapper scripts (`run_prepare_servers.sh`, `run_xui.sh`)

## Ansible from zero

| Unit | Owns |
|------|------|
| `prepare_servers` | apt baseline, admin user, SSH keys, Docker CE, optional sshd harden |
| `xui_docker` | Compose, ACME, panel bootstrap, Xray autoconfigure, extra inbounds, SSH tunnel, timers |
| `host_metrics` | sysstat, vnstat, disk snapshot helpers |
| Inventory | groups: prepare / main / proxy / metrics; host_vars per node |
| Runner | Docker image with ansible-core + jmespath; host-net + mounted key |

Tags for partial apply: `preflight`, `ufw`, `ssl`, `compose`, `panel`, `xray`/`autoconfigure`, `routing`, `extra_inbounds`, `ssh_tunnel`, `scheduled_restart`.

Idempotency: client UUID registry, extra-inbound password registry, inbound-summary JSON consumed by the proxy play so jump outbounds are generated from **main artifacts**, not typed by hand.

## What the Xray role actually does

| Concern | Implementation |
|---------|----------------|
| Image pin | Compose image version in vars (not `latest`) |
| TLS | acme.sh HTTP-01 (port 80), UFW 22/80/443/panel |
| Panel | first-init, token, `webBasePath`, artifacts `panel-access.json` |
| Inbound | API create/sync (not only UI); Reality-class stream settings from vars |
| Clients | list in group_vars → `vless://` export files |
| Proxy routes | `xui_proxy_routes[]` → outbound JSON; active tag switchable |
| Per-inbound routing | optional: each inbound tag → its outbound (not one default for all) |
| Extra inbounds | additional protocols from a list (same active outbound on jump) |
| Restart | systemd timer → `docker kill --signal=USR1` (core only) or full container restart |
| Failover | socat unit + `nologin` users with `permitopen=` to localhost tunnel port |

Crypto/stream knobs (keepalives, congestion, post-quantum auth options) live in vars/templates. They are **not** a public how-to; the point for hiring is: the core is **data**, the role is **API + files**, rebuild is **one command**.

## Operator UX

1. `prepare_servers` on new VPS (passwords generated into artifacts, not committed)
2. SSH as the admin user with the deploy key
3. `--main` then `--proxy` (proxy needs inbound-summary from main)
4. `--tags routing -e …_outbound_tag=…` to fail over the jump exit
5. `--tags ssh_tunnel` to refresh the backup channel only

Same wrappers ran from **WSL + Docker Desktop**, then from **native Arch** (`docker` group, compose plugin). CRLF is banned (`.gitattributes` `eol=lf`) so playbooks do not die with `bash\r`.

## Proof of code

Slim public kits (no dest/SNI values, no panel passwords, no real inventory). The **full task graph** is in `roles/xui_docker/` (panel API, inbound sync, extra inbounds, routing tags, ACME, socat):

| Kit | Path |
|-----|------|
| Host baseline | [`../../reference/ansible-bootstrap/`](../../reference/ansible-bootstrap/) |
| Edge panel role | [`../../reference/ansible-edge/`](../../reference/ansible-edge/) (`roles/xui_docker/`, playbooks `xui_main.yml` / `xui_proxy.yml`) |
| Host metrics | [`../../reference/monitoring-starter/`](../../reference/monitoring-starter/) |
| Runner image | [`../../reference/utilities/ansible-runner/`](../../reference/utilities/ansible-runner/) |
| SSH clients | [`../../reference/apps/ssh-tunnel-android/`](../../reference/apps/ssh-tunnel-android/), [`../../reference/apps/ssh-tunnel-docker/`](../../reference/apps/ssh-tunnel-docker/) |

IaC map: [`../../iac/ansible/`](../../iac/ansible/).

See [`../../diagrams/practice/home-lab/edge-platform.md`](../../diagrams/practice/home-lab/edge-platform.md).

## Keywords

Ansible, Docker, Compose, GitOps, TLS, ACME, UFW, systemd, inventory, roles, tags, Xray, API automation, jump host, SSH, observability
