# monitoring-starter

Light host metrics as Ansible: **sysstat** (sar), **vnstat**, disk-usage CSV snapshots, a report script, and a sudoers drop-in so the deploy user can read logs without a password.

Not Prometheus/Grafana — day-2 visibility on a small fleet before a full observability stack. Same inventory groups as the edge platform.

Practice: [`../../practice/home-lab/edge-platform.md`](../../practice/home-lab/edge-platform.md). Bootstrap: [`../ansible-bootstrap/`](../ansible-bootstrap/).

```bash
cp inventories/hosts.ini.example inventories/hosts.ini
ansible-playbook -i inventories/hosts.ini playbooks/host_metrics.yml
```

On the host: `/usr/local/bin/host-metrics-report.sh today|week|month`.

## Keywords

sysstat, vnstat, systemd timers, Ansible, host metrics
