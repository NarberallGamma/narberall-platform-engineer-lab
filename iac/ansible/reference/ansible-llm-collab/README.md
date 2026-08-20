# LLM collab Ansible (GPU inference, Nextcloud, Kafka, n8n)

**Business first:** a **private OpenAI-compatible API** so accounting, analysts, and developers stop pasting tenant files into a public chat. The same inventory runs the **collab plane** (Nextcloud groupfolders, n8n, Kafka) and host harden (CIS, AD/SSSD, EDR). Buyer page: [`../../../../docs/for-business.md`](../../../../docs/for-business.md). Manager LLMOps: [`../../../../architecture/01-llmops.md`](../../../../architecture/01-llmops.md). Case: [`../../../../case-studies/01-ai-llm-platform.md`](../../../../case-studies/01-ai-llm-platform.md).

I publish this tree as the **living** Ansible I used for that job. It is not a three-task demo and not only a GPU compose. Role graphs, Jinja, client matrices, and run wrappers stay intact. Brand, live IPs, Vault ciphertext, and EDR packages are stripped.

This kit is **Ansible on an estate map**. Home-lab compose (Ollama / SD / Kohya) stays under [`../../../../practice/home-lab/ai-lab.md`](../../../../practice/home-lab/ai-lab.md). Host baseline for an empty VPS stays in [`../ansible-bootstrap/`](../ansible-bootstrap/). Hub: [`../`](../).

## Who this kit is for

| Reader | What to take |
|--------|----------------|
| Founder / PM | Tenant data stays on a company GPU. Folder ACL and n8n forms are GitOps, not a ticket per client. OCR/1C hosts sit on the same map as the LLM node. |
| Hiring lead | One inventory: GitLab, Nextcloud HA, JSM, 1C, ContentCapture-class, Redis, Patroni-class PG, Kafka, Teleport, proxies. Roles match that map. |
| Engineer | Playbooks and `group_vars` below. Capacity knobs (VRAM, context, quant) live in `group_vars/llm_dev/`. |

```text
ansible-llm-collab/
  playbooks/                 # prepare, CIS, llm-dev, Nextcloud, n8n, Kafka, bootstrap users
  roles/                     # full roles, including vendored ansible-lockdown.ubuntu24_cis
  group_vars/                # living vars; secrets are CHANGE_ME / Vault key names only
  inventories/
    hosts.ini.example        # every original group; fake FQDNs and doc IPs
    localhost/hosts.ini
    estate_teleport.ini
  scripts/run/               # Docker control-node wrappers (ssh-agent, Vault env)
  scripts/db_migration/      # PostgreSQL create / dump-restore / owner / lock
  extras/sec-stack/          # VictoriaMetrics / Grafana / node_exporter (renamed from a private metrics kit)
```

## What this tree actually contains

The inventory is a **collab + GPU estate**, not a single `llm-dev` host.

| Plane | Groups in `inventories/hosts.ini.example` | Why it is in this kit |
|-------|------------------------------------------|------------------------|
| Private LLM | `llm_dev` | GPU VM: GGUF fetch, llama.cpp CUDA, Open WebUI, nginx TLS `/v1` |
| Files / ACL | `nextcloud_dev`, `nextcloud_prod_cluster` (active + backup), `nextcloud_regul` | Client folder matrix, WebDAV MKCOL, occ ACL |
| Automation | n8n playbook on localhost + `run_nextcloud_groupfolders.sh` | Form + webhook GitOps so a PM can reapply ACL without SSH |
| Brokers / cache | `kafka`, `redis_cluster` | KRaft + AKHQ; Redis next to the same map |
| Identity / jump | `prepare` (AD/SSSD/EDR), Teleport-class host in `infra` | Who can reach the GPU and the file plane |
| Documents / ERP | `contentcapture_prod`, `1c`, `db_platform`, `postgresql_prod` | OCR and 1C sit next to the LLM API on purpose |
| Collab apps | `gitlab`, `sd_prod`, `jsm_dev`, `app`, `docker_hosts` | The same Ansible habit as the GPU node |
| Edge / scan / backup | `proxy`, `cs_scanner`, `infra` (LB, ELK, Veeam-class) | Estate map kept whole so a reviewer sees scale |

`scripts/db_migration/` is PostgreSQL move tooling (create empty DBs, parallel dump/restore, owner change, read-only lock) used when those 1C-class databases change host. Passwords stay out of the scripts.

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| `llm_dev_*` | GGUF catalog (Qwen 9B Q4_K_M), llama.cpp CUDA server, Open WebUI, nginx TLS `/v1`, Ouroboros chat-template patch (clients that omit `role=system`), cgroup / VRAM knobs for a **16 GiB** GPU (V100-class; ctx ladder from 262144 down) |
| `nextcloud_groupfolders` | Profile map (dev / prod / regul), WebDAV MKCOL, occ ACL batches, LDAP reset, all-clients reapply |
| `n8n_workflows` | GitOps sync of **form + webhook** JSON into n8n via REST; Execute-command back to the Ansible control node |
| `kafka_deploy` | KRaft, SASL PLAIN, optional SASL_SSL, AKHQ, Vault-sourced CLUSTER_ID |
| `prepare_servers` + CIS | Timezone, AD/SSSD, Docker CE migrate, NVIDIA CDI, EDR agent, lockdown Ubuntu 24 with known conflicts documented |
| `extras/sec-stack` | Metrics stack + node_exporter on Teleport/DB hosts, SOPS placeholder for Grafana / PAN-OS / EDR exporter |
| `scripts/db_migration/` | Parallel PG dump/restore when the document/1C databases move |

```bash
cp inventories/hosts.ini.example inventories/hosts.ini
ansible-galaxy collection install -r requirements.yml
# control-node image (override ANSIBLE_IMAGE as needed)
./scripts/run/run_llm_dev.sh --limit llm-dev-01.example.com --ssh-key /path/to/key --ssh-agent
./scripts/run/run_nextcloud_groupfolders.sh --profile nextcloud-dev --limit nextcloud-dev.example.com "Example Client"
./scripts/run/run_kafka.sh --limit kafka-prod.example.com
./scripts/run/run_prepare_servers.sh --limit app-02.example.com
```

Without the wrapper, the same playbooks run from this directory with `-i inventories/hosts.ini`. n8n sync uses `inventories/localhost/hosts.ini`.

## Playbooks

| Playbook | Scope |
|----------|-------|
| `playbooks/llm_dev_deploy.yml` | GPU host: model fetch, llama.cpp, WebUI, nginx |
| `playbooks/nextcloud_groupfolders.yml` | Folder matrix + ACL (profile or `--limit`) |
| `playbooks/n8n_workflows.yml` | Sync form + webhook JSON into n8n (Nextcloud ACL GitOps) |
| `playbooks/kafka_deploy.yml` | Kafka KRaft (+ optional AKHQ) |
| `playbooks/prepare_servers.yml` | Host prepare for group `prepare` |
| `playbooks/cis_ubuntu24.yml` | CIS Ubuntu 24 (lockdown role) |
| `playbooks/setup_bootstrap_users.yml` | `ansible` + `gitlab-runner` users and keys |

## Roles

| Role | Job |
|------|-----|
| `llm_dev_init` | Vault keys (API, HF, WebUI) |
| `llm_dev_model_fetch` | Hugging Face GGUF + manifest |
| `llm_dev_ouroboros_compat` | Patched Qwen chat template (no mandatory leading system) |
| `llm_dev_deploy` | llama.cpp + Open WebUI compose |
| `llm_dev_nginx` | TLS vhost, `/v1` prefix rewrite |
| `prepare_nvidia_gpu` | Driver / toolkit / CDI when the LLM play asks |
| `nextcloud_init` / `nextcloud_groupfolders` | Vault WebDAV + matrix apply |
| `n8n_init` / `n8n_workflows` | API key + REST sync |
| `kafka_init` / `kafka_deploy` | Vault SASL / CLUSTER_ID + compose |
| `prepare_servers` | AD, DNS, Docker, EDR, hardening toggles |
| `ansible-lockdown.ubuntu24_cis` | Vendored UBUNTU24-CIS 1.6.0 |

## extras/sec-stack

Separate inventory (`inventory/hosts.yml`). Role `sec_stack` renders compose env and Alertmanager from group_vars. Live SOPS ciphertext is not in git. Copy `inventory/group_vars/sec_stack/secrets.sops.yml.example` and encrypt locally.

```bash
cd extras/sec-stack
ansible-playbook -i inventory/hosts.yml playbooks/site.yml
```

## Inventory contract

- Copy `inventories/hosts.ini.example` to `inventories/hosts.ini` (gitignored)
- Group names and vars stay as in the original tree (`llm_dev`, `nextcloud_regul`, `db_platform`, `prepare`, …)
- Hostnames are `*.example.com`; IPs are `10.10.x.x` or documentation ranges
- Vault mount name is `platform-infra` / path `Ubuntu_servers` (key names only)
- Matrices: `group_vars/env/matrix_*_platform.yaml`
- Bootstrap SSH publics in `group_vars/all.yml` are `CHANGE_ME`

## Keywords

Ansible, LLM, llama.cpp, NVIDIA, nginx, Nextcloud, n8n, Kafka, CIS, Ubuntu, Docker, Vault, GitLab CI, VictoriaMetrics, Grafana, ContentCapture, 1C, PostgreSQL, Teleport, OpenAI-compatible API
