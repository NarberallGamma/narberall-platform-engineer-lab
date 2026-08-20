# Host cybersec metrics (sec-stack)

**Business first:** host Grafana and VictoriaMetrics sit on a **VM**, not in the cluster overlay. Hub: [`../../../../`](../../../../). LLM kit: [`../../`](../../). In-cluster half: [`../../../../../helm/reference/helm-estate-cluster/monitoring/`](../../../../../helm/reference/helm-estate-cluster/monitoring/). Manager page: [`../../../../../../architecture/05-sre.md`](../../../../../../architecture/05-sre.md). Catalog: [`../../../../../../docs/sre/layers.md`](../../../../../../docs/sre/layers.md).

I used this extra as the **host** metrics plane next to the LLM/collab inventory: VictoriaMetrics + Grafana + Alertmanager + vmalert, node-exporter on Teleport/DB hosts, PAN-OS and EDR exporters. Tokens and API keys come from SOPS (`secrets.sops.yml.example`). Compose `stack/` (images and dashboards the role copies onto the VM) is not published; this folder keeps the roles and the SOPS contract.

```text
sec-stack/
  playbooks/site.yml
  inventory/                 # example FQDNs; secrets.sops.yml.example
  roles/
    dns/
    docker/
    node_exporter/
    sec_stack/               # render alertmanager + .env, compose up
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Two plays | `sec_stack` host gets the VM stack; `teleport:teleport_db` get node-exporter only |
| SOPS contract | Grafana admin, Telegram bot, PAN-OS API keys, EDR collector YAML, registry token. Example file uses placeholders |
| Alertmanager template | Dual Telegram chats (default vs critical). Heartbeat URL for a dead-man's switch |
| EDR / PAN-OS | Exporter configs from SOPS; coverage CSV and exclusions live under `/opt/sec-stack` on the VM |
| Honest gap | `stack/` compose tree is not in this lab. Roles still show how the VM is wired |

```bash
# from this directory, after filling inventory and decrypting SOPS:
ansible-playbook -i inventory/hosts.yml playbooks/site.yml
```

Do not merge this with the Helm Grafana overlay. Complementary layers: [`../../../../../helm/README.md#observability-split-do-not-duplicate-ansible`](../../../../../helm/README.md#observability-split-do-not-duplicate-ansible).

**Keywords:** VictoriaMetrics, Grafana, Alertmanager, vmalert, node-exporter, PAN-OS, EDR, SOPS
