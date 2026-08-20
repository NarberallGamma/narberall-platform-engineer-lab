# docker_app: одно compose-приложение в /docker/apps/<slug>

| App | Playbook | Inventory | group_vars |
|-----|----------|-----------|------------|
| cert-monitoring | `docker_app_cert_monitoring.yml` | `[cert_monitoring]` | `cert-monitoring.yml` |
| cert-orchestrator | `docker_app_cert_orchestrator.yml` | `[cert_orchestrator]` | `cert-orchestrator.yml` |
| cloud-hibernate-operator | `docker_app_cloud_hibernate_operator.yml` | `[cloud_hibernate_operator]` | `cloud-hibernate-operator.yml` |
| gitlab-nginx | `docker_app_gitlab_nginx.yml` | `[gitlab_nginx]` | `gitlab-nginx.yml` |
| edge-lb | `docker_app_edge_lb.yml` | `[edge_lb]` | `edge-lb.yml` |

Legacy migrate: `migrate_gitlab_nginx_legacy.yml`, `migrate_edge_lb_legacy.yml` (edge-lb migrate завершён; switch в group_vars).

Vault: mount `ansible`, path = slug сервиса. Имена ключей в секрете: `docker_app_vault_key_map` в group_vars (подключение через `vars_files` в плейбуке).

См. `docs/DOCKER_APPS.md`, `docs/DOCKER_APPS_VAULT_SECRETS.md`
