# prepare_vps_cluster

Подготовка VPS для blockchain egress после `prepare_servers`.

## Блоки

| Блок | Переключатель | Описание |
|------|---------------|----------|
| Docker check | `enable_vps_docker_check` | `docker info`, `docker compose version`; установка не выполняется |
| Admin user | `enable_vps_admin_user` | `admin_vps`, группа `sudo`, sudo NOPASSWD, пароль 30 символов, `artifacts/vps_cluster_credentials/` |
| SSH | `enable_vps_ssh` | `PermitRootLogin` по `vps_ssh_disable_root_login` (по умолчанию root разрешён) |
| chrony | `enable_vps_chrony` | синхронизация времени |
| ufw | `enable_vps_firewall` | deny incoming; `:443` только с `vps_k8s_egress_source_cidrs`; SSH по правилам ниже |
| Envoy | `enable_vps_envoy` | `/docker/apps/envoy/docker-compose.yml`, SNI dynamic forward proxy |
| Envoy logging | `enable_vps_envoy_logging` | access log в `logs/access.log`, logrotate `/etc/logrotate.d/envoy-egress` |

## Пути на хосте

- Приложения: `{{ vps_docker_apps_base_dir }}/<app>/` (по умолчанию `/docker/apps/envoy/`).
- Compose и `envoy.yaml` генерируются из templates роли.
- Access log (при `enable_vps_envoy_logging`): `{{ vps_docker_apps_base_dir }}/envoy/logs/access.log`.
- logrotate: `/etc/logrotate.d/envoy-egress` (daily, rotate 7, gzip, copytruncate).

Формат строки access log: downstream IP, SNI, upstream host, bytes, duration. При `vps_envoy_access_log_to_stdout: true` дублируется в `docker logs`.

## Переменные

См. `group_vars/vps_cluster.yml`.

## Теги

`prepare_vps`, `vps`, `docker`, `admin_user`, `firewall`, `envoy`, `envoy_logging`, `ssh`, `chrony`, `health`

Только логирование на уже подготовленных VPS:

```bash
ansible-playbook playbooks/prepare_vps_cluster.yml --limit estate-vps-cluster-01 --tags envoy_logging,envoy
```

## Admin user

- Переменные: `vps_admin_username`, `vps_admin_ssh_public_keys`, `vps_admin_regenerate_password`, `vps_admin_sudo_nopasswd`.
- При `vps_admin_sudo_nopasswd: true` создаётся `/etc/sudoers.d/<user>` с `NOPASSWD:ALL` и проверкой `visudo`.
- После первого создания (или при `vps_admin_regenerate_password: true`) пароль в:
  `artifacts/vps_cluster_credentials/<hostname>/admin_vps_credentials.txt` (каталог в `.gitignore`).
