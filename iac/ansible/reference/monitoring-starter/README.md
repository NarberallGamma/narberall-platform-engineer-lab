# monitoring-starter

Light host metrics as Ansible: **sysstat** (sar), **vnstat**, disk-usage CSV snapshots, a report script, and a sudoers drop-in so the deploy user can read logs without a password.

The role is complete for that job (tasks + systemd timers + report script + sudoers). It is not a cut of Prometheus. Estate scrape and compose live in [`../ansible-app-platform/`](../ansible-app-platform/) (`monitoring_deploy`, `node_exporter`) and [`../ansible-estate/`](../ansible-estate/) (`node-exporter`). In-cluster Grafana / OpenObserve overlay is Helm: [`../../../helm/reference/helm-estate-cluster/monitoring/`](../../../helm/reference/helm-estate-cluster/monitoring/). How I use those product APIs: [`../../../../architecture/05-sre.md`](../../../../architecture/05-sre.md), [`../../../../docs/sre/`](../../../../docs/sre/).

Practice: [`../../../../practice/home-lab/edge-platform.md`](../../../../practice/home-lab/edge-platform.md). Bootstrap: [`../ansible-bootstrap/`](../ansible-bootstrap/).

```bash
cp inventories/hosts.ini.example inventories/hosts.ini
ansible-playbook -i inventories/hosts.ini playbooks/host_metrics.yml
```

On the host: `/usr/local/bin/host-metrics-report.sh today|week|month`.

## Keywords

sysstat, vnstat, systemd timers, Ansible, host metrics
