# docker_app: one compose application under /docker/apps/<slug>

| App | Playbook | Inventory | group_vars |
|-----|----------|-----------|------------|
| cert-monitoring | `docker_app_cert_monitoring.yml` | `[cert_monitoring]` | `cert-monitoring.yml` |
| cert-orchestrator | `docker_app_cert_orchestrator.yml` | `[cert_orchestrator]` | `cert-orchestrator.yml` |
| cloud-hibernate-operator | `docker_app_cloud_hibernate_operator.yml` | `[cloud_hibernate_operator]` | `cloud-hibernate-operator.yml` |
| gitlab-nginx | `docker_app_gitlab_nginx.yml` | `[gitlab_nginx]` | `gitlab-nginx.yml` |
| edge-lb | `docker_app_edge_lb.yml` | `[edge_lb]` | `edge-lb.yml` |

Legacy migrate: `migrate_gitlab_nginx_legacy.yml`, `migrate_edge_lb_legacy.yml` (edge-lb migrate is complete; switch is in group_vars).

Vault: mount `ansible`, path = service slug. Secret key names: `docker_app_vault_key_map` in group_vars (wired via `vars_files` in the playbook).

See `docs/DOCKER_APPS.md`, `docs/DOCKER_APPS_VAULT_SECRETS.md`
