# Nextcloud clients (fpm + nginx + clamav)

**Business first:** the file plane is **fpm behind nginx, plus clamav and cron**, not an `occ` playbook. Hub: [`../../../`](../../../). Collab index: [`../`](../). Ansible ACL sibling: [`../../../../ansible/reference/ansible-llm-collab/`](../../../../ansible/reference/ansible-llm-collab/). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).

I used this richer clients stack: `nextcloud:31.0.6-fpm`, `nginx:1.25.1` bound to `10.10.1.11:443`, `clamav/clamav:stable_base`, a cron sidecar (`nextcloud:apache` + `/cron.sh`), and Redis. Data dirs are named bind volumes under `./Volumes/`.

```text
nextcloud/
  docker-compose.yml    # five live services; exporter left commented
```

```bash
# from this directory, after nginx.conf, www.conf, mycronfile, TLS under
# /docker/SSL_certs/example, and Volumes/* exist:
docker compose up -d
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Split fpm / nginx | PHP is not the TLS terminator |
| Clamav socket volume | Scan next to the app, not a later ticket |
| Cron sidecar | Same data volume, dedicated image |
| Bind `device:` volumes | Host paths stay next to compose, not anonymous |

## Honest gap

`nginx.conf`, `www.conf`, `mycronfile`, TLS, and `./Volumes/` are not in git. The commented exporter needs a token. Poorer internal Nextcloud hosts (no clamav) were not published. Ansible groupfolders / occ ACL are a different mechanic.

**Keywords:** Nextcloud, php-fpm, nginx, ClamAV, Redis, cron
