# Host cybersec compose (sec-stack)

**Business first:** firewalls, EDR coverage, and Teleport TLS sit on one **VM** scrape plane so a hole is a PromQL alert, not a spreadsheet. Ansible extra (roles + SOPS, same tree as [`stack/`](../../../ansible/reference/ansible-llm-collab/extras/sec-stack/stack/)): [`../../../ansible/reference/ansible-llm-collab/extras/sec-stack/`](../../../ansible/reference/ansible-llm-collab/extras/sec-stack/). In-cluster overlay (do not merge): [`../../../helm/reference/helm-estate-cluster/monitoring/`](../../../helm/reference/helm-estate-cluster/monitoring/). Manager page: [`../../../../architecture/05-sre.md`](../../../../architecture/05-sre.md). Catalog: [`../../../../docs/sre/layers.md`](../../../../docs/sre/layers.md). Sanitize: [`../../SANITIZE.md`](../../SANITIZE.md).

I used this compose as the living stack the Ansible role copies onto `/opt/sec-stack` (`src: "{{ playbook_dir }}/../../stack/"`). The identical files live next to that extra as [`stack/`](../../../ansible/reference/ansible-llm-collab/extras/sec-stack/stack/) so the copy path resolves. Tokens stay in `.env.example` and SOPS. I query VictoriaMetrics the same way I edit Grafana views in the Helm overlay.

```text
sec-stack/
  docker-compose.yml         # 8 services, pinned VM / Grafana / Alertmanager / blackbox
  .env.example               # Grafana admin + PANOS_API_KEY_* = CHANGE_ME
  alertmanager/              # route + inhibit; Telegram template
  blackbox/blackbox.yml
  vmagent/prometheus.yml     # self, PAN-OS multi-target, EDR, Teleport, TLS/ICMP
  vmalert/rules/             # palo-alto, edr, teleport, certificates, meta
  grafana/
    provisioning/            # VictoriaMetrics datasource + file provider
    dashboards/              # sec-stack-overview + edr-coverage
  exporters/panos/           # Dockerfile + multi-target XML API exporter
  exporters/edr/             # aliases + exclusions; image is a registry pin
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Eight-service compose | VictoriaMetrics / vmagent / vmalert **1.147.0**, Grafana **13.1.0**, Alertmanager **0.33.1**, blackbox **0.28.0**, `panos-exporter` build, `edr-exporter` pin `example.registry/sec/edr-coverage:v0.7.2`. |
| `exporters/panos/` | Slim Python image, 358-line multi-target XML API, seven `*.example.com` firewalls, IPsec roles (`primary` / `reserve` / `broken`). |
| `vmalert/rules/` | **24** alerts across five files: 11 PAN-OS (HA / IPsec / license / cert / session), 4 EDR coverage, 4 Teleport / node, 3 TLS probe, DeadManSwitch + ScrapeTargetDown. |
| Grafana | Two provisioned dashboards (`sec-stack-overview`, `edr-coverage`). File provider, sidecar off. |
| Twin path | Same tree as [`../../../ansible/reference/ansible-llm-collab/extras/sec-stack/stack/`](../../../ansible/reference/ansible-llm-collab/extras/sec-stack/stack/). Role `copy` needs that folder. |

```bash
cp .env.example .env
# fill CHANGE_ME (Grafana password + one PAN-OS API key per firewall)
docker compose up -d --build
```

Deploy via Ansible (renders Alertmanager + `.env` from SOPS, then `compose up` in `/opt/sec-stack`):

```bash
# from iac/ansible/reference/ansible-llm-collab/extras/sec-stack/
ansible-playbook -i inventory/hosts.yml playbooks/site.yml
```

Do not merge this with the Helm Grafana overlay. Complementary layers: [`../../../helm/README.md#observability-split-do-not-duplicate-ansible`](../../../helm/README.md#observability-split-do-not-duplicate-ansible).

## Honest leftovers

- `edr-exporter` is a **pin**. Collector source is [`../../images/operators/edr-coverage/`](../../images/operators/edr-coverage/). This tree only ships aliases and exclusions.
- `exporters/edr/data/` and `exporters/edr/config/` are created on the VM by the Ansible role. They are not in git.
- `node` scrape jobs in `vmagent/prometheus.yml` stay commented (`<TELEPORT_IP>` placeholders).
- PAN-OS keys and Grafana password are `CHANGE_ME`. Live SOPS stays out.
- Terraform for the cybersec VM is not in this kit.

**Keywords:** Docker Compose, VictoriaMetrics, Grafana, Alertmanager, vmalert, vmagent, blackbox, PAN-OS, EDR, node-exporter, Teleport
