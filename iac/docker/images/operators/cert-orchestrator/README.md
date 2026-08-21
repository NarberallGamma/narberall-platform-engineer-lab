# Cert orchestrator (Let’s Encrypt DNS-01, Kubernetes, SSH)

**Business first:** a wildcard is a scheduled job, not a Friday `kubectl`. I renew at the registrar with DNS-01, then lay the same PEM into cluster TLS secrets and onto nginx hosts.

Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md). Estate deploy of the same image (Ansible `.j2`, healthcheck, telegram egress): [`../../../../ansible/reference/ansible-estate/roles/docker_app/templates/cert-orchestrator/`](../../../../ansible/reference/ansible-estate/roles/docker_app/templates/cert-orchestrator/). Experience: [`../../../../../docs/experience.md`](../../../../../docs/experience.md).

This tree is **real Python**. The DNS vendor API is **REG.RU** (`api.reg.ru`). I vendored `certbot-regru` so the image builds without a second clone. Compose sits next to the Dockerfile. That raw file is not a replacement for the Ansible template.

```text
cert-orchestrator/
  Dockerfile                 # python:3.11-alpine, kubectl v1.29.0, certbot + vendor plugin
  docker-compose.yml         # image-adjacent raw compose (env-file mounts)
  .env.example               # registry tag, host paths, K8S_TOKEN, optional REG.RU / Telegram
  example-config.yaml        # schedule, REG.RU, k8s namespaces, nginx remotes
  .gitignore                 # .env and config.yaml stay out
  requirements.txt           # PyYAML, aiohttp
  src/                       # 15 modules: daemon, certbot, k8s, SSH, Telegram, state
  vendor/certbot-regru/      # MIT plugin, FORK.md (no pip install of regru.ini)
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| `src/pipeline.py` | One run: certbot → kubectl TLS secrets → SSH nginx → optional HTTPS check. One failed namespace does not stop the rest. |
| `vendor/certbot-regru/` | Certbot 3.x entry point `dns`. Flags `--dns-credentials` and `--dns-propagation-seconds`. INI is built from env or YAML, not baked into the image. |
| `src/k8s_tls.py` | ServiceAccount token + CA mount. No kubeconfig. `kubectl create secret tls` then replace. |
| `src/ssh_remote.py` | SCP PEM, then reload: `docker exec <slug>` when `ssl_dir` is `/docker/apps/<slug>/certs`, else systemd nginx. Override with `nginx_container`. |
| `src/scheduler.py` | `days_interval`, weekday, `time_hhmm`, optional `renew_on_container_start`. |
| `docker-compose.yml` | Host paths via `.env`. Same contract as `.env.example`. |

```bash
cp .env.example .env
cp example-config.yaml config.yaml
# substitute CHANGE_ME; mount a real SSH key and k8s-ca.crt (not in git)
docker build -t cert-orchestrator:1.0 .
docker compose --env-file .env up -d
docker compose exec cert-orchestrator python main.py renew
docker compose exec cert-orchestrator python main.py renew --force
docker compose exec cert-orchestrator python main.py verify-https
```

Image-only run (no compose):

```bash
docker run -d --name cert-orchestrator --restart always \
  -v /path/to/config.yaml:/etc/cert-orchestrator/config.yaml:ro \
  -v /etc/letsencrypt:/etc/letsencrypt \
  -v /path/to/id_rsa:/ssh/id_estate:ro \
  -e TZ=Europe/Moscow \
  -e K8S_TOKEN=CHANGE_ME \
  example.registry/estate/base-images/cert-orchestrator:1.1
```

## CLI

Entry: `python main.py [--config path] <command>`. Default `CONFIG_FILE` is `/etc/cert-orchestrator/config.yaml`. Image `CMD` is `daemon`.

| Command | Job |
|---------|-----|
| `daemon` | Schedule loop (image default) |
| `renew` | One full pipeline |
| `renew --force` | Same plus certbot `--force-renewal` |
| `verify-https` | Only `https_verification` |

State lives in `CERT_ORCHESTRATOR_STATE_DIR` (default `/var/lib/cert-orchestrator`). Telegram gets a per-step 🟢/🔴 summary. Fatal alerts are certbot or credentials only.

`targets.*.host` must be reachable **from the container**.

## Honest gaps

- REG.RU is the registrar this estate used. The plugin talks to that public API. It is not a generic ACME DNS abstraction.
- Live PEM, `k8s-ca.crt`, SSH private keys, and a filled `.env` stay out of git.
- Ansible `docker_app` already ships a **different** compose: bind-mount `./config`, `./.ssh`, `./.k8s`, healthcheck, telegram-egress snippets. This folder is the image plus the raw compose that file does not replace.
- `.env.example` pins image tag `1.1`. Compose default is `1.0` when `CERT_ORCHESTRATOR_IMAGE` is unset.

## Keywords

Docker, Compose, Python, Certbot, Let’s Encrypt, DNS-01, REG.RU, Kubernetes TLS Secret, SSH, nginx, Telegram
