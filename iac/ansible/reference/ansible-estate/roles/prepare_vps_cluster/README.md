# prepare_vps_cluster

Prepare VPS hosts for blockchain egress after `prepare_servers`.

## Blocks

| Block | Toggle | Description |
|------|---------------|----------|
| Docker check | `enable_vps_docker_check` | `docker info`, `docker compose version`; install is not performed |
| Admin user | `enable_vps_admin_user` | `admin_vps`, `sudo` group, sudo NOPASSWD, 30-character password, `artifacts/vps_cluster_credentials/` |
| SSH | `enable_vps_ssh` | `PermitRootLogin` from `vps_ssh_disable_root_login` (root allowed by default) |
| chrony | `enable_vps_chrony` | time sync |
| ufw | `enable_vps_firewall` | deny incoming; `:443` only from `vps_k8s_egress_source_cidrs`; SSH per rules below |
| Envoy | `enable_vps_envoy` | `/docker/apps/envoy/docker-compose.yml`, SNI dynamic forward proxy |
| Envoy logging | `enable_vps_envoy_logging` | access log in `logs/access.log`, logrotate `/etc/logrotate.d/envoy-egress` |

## Paths on the host

- Applications: `{{ vps_docker_apps_base_dir }}/<app>/` (default `/docker/apps/envoy/`).
- Compose and `envoy.yaml` are generated from the role templates.
- Access log (when `enable_vps_envoy_logging`): `{{ vps_docker_apps_base_dir }}/envoy/logs/access.log`.
- logrotate: `/etc/logrotate.d/envoy-egress` (daily, rotate 7, gzip, copytruncate).

Access log line format: downstream IP, SNI, upstream host, bytes, duration. When `vps_envoy_access_log_to_stdout: true` it is also written to `docker logs`.

## Variables

See `group_vars/vps_cluster.yml`.

## Tags

`prepare_vps`, `vps`, `docker`, `admin_user`, `firewall`, `envoy`, `envoy_logging`, `ssh`, `chrony`, `health`

Logging only on already prepared VPS hosts:

```bash
ansible-playbook playbooks/prepare_vps_cluster.yml --limit estate-vps-cluster-01 --tags envoy_logging,envoy
```

## Admin user

- Variables: `vps_admin_username`, `vps_admin_ssh_public_keys`, `vps_admin_regenerate_password`, `vps_admin_sudo_nopasswd`.
- When `vps_admin_sudo_nopasswd: true`, `/etc/sudoers.d/<user>` is created with `NOPASSWD:ALL` and checked by `visudo`.
- After the first create (or when `vps_admin_regenerate_password: true`) the password is in:
  `artifacts/vps_cluster_credentials/<hostname>/admin_vps_credentials.txt` (directory is in `.gitignore`).
