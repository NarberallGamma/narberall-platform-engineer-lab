# Superset (estate prod) — Docker Compose

Stack based on the official [apache/superset](https://hub.docker.com/r/apache/superset) image with a pinned tag **`6.0.0`**: Gunicorn, Celery worker, Celery beat. **PostgreSQL** and **Redis** are containers in the same `docker-compose.yml`; the only host bind is **`127.0.0.1:8088`** for the reverse proxy. TLS is on a separate **nginx** `1.29.0` (`network_mode: host`), same pattern as `estate-prod-app-1` under `/docker/nginx`.

Commands and service names follow upstream [docker-compose-non-dev.yml](https://github.com/apache/superset/blob/master/docker-compose-non-dev.yml) (`app-gunicorn`, `docker-init.sh`, `docker-bootstrap.sh` for worker/beat). Upstream states that compose is not positioned as production; for estate this is a deliberate self-hosted variant with external nginx and localhost port binds. Differences from upstream: **Docker Hub** image instead of `build`, **`init` profile** on `superset-init` (a repeat `docker compose up -d` does not re-run init), **bind mounts** for data and a **read-only** `pythonpath` instead of volumes from the development repository. PostgreSQL image version is **`postgres:17-alpine`**, same as non-dev.

### Where data lives

| Data | Location |
|------|----------|
| Superset metadata (dashboards, datasets, users) | Volume **`./data/postgres`** (PostgreSQL 17 in the `db` container) |
| Celery cache and queues | Volume **`./data/redis`** (Redis 7 in the `redis` container, AOF) |
| Application home (`SUPERSET_HOME` → `/app/superset_home`) | **`./data/superset_home`** relative to `docker-compose.yml` |

Volume directories are created on first start; to create them in advance: `mkdir -p data/postgres data/redis data/superset_home`.

## Location on the server

Copy the `superset` directory to `/docker/superset` (or `/docker/apps/superset`) on `estate-prod-superset` (a separate `/docker` disk is already mounted).

## Configuration

1. `cp env.example .env`
2. Create a trusted CA bundle for the container (volume `./ca-certificates.crt` in `docker-compose.yml`): on Linux
   `sh scripts/prepare-ca-bundle.sh`
   or copy the host `/etc/ssl/certs/ca-certificates.crt` to `ca-certificates.crt` next to compose (the file is in `.gitignore`).
3. Fill `SUPERSET_SECRET_KEY`, `POSTGRES_PASSWORD`, `ADMIN_PASSWORD`. After init the first UI login is user **`admin`**, password from `ADMIN_PASSWORD` (in upstream `docker-init.sh` for 6.0.0 the login and `admin@superset.com` are hardcoded).
4. **OAuth / ADFS (prod):** in `.env` set `SUPERSET_AUTH_TYPE=oauth`, `OAUTH_CLIENT_ID`, `OAUTH_CLIENT_SECRET` (confidential strings from the ADFS application registration). Adjust `OAUTH_SERVER_METADATA_URL`, `ADFS_EXTRA_HOST_ENTRY`, `OAUTHLIB_INSECURE_TRANSPORT` when needed.
5. Place `example.com.crt` and `example.com.key` in `nginx/certs/` (the same files as on app01).

### ADFS login and what is configured where

- **ADFS:** issues the OIDC token and Windows group membership (`Estate Superset Administrators` and similar). Group names in the token must match the keys in `AUTH_ROLES_MAPPING` in `pythonpath/superset_config.py`. JWT fields (`upn`, `email`, `roles`, …) are set on the ADFS side and must match what `custom_sso_security_manager.py` expects.
- **Superset UI:** connections to **databases** (dashboard sources, SQL Lab), dataset grants, row-level security, and roles on top of those already assigned from groups — this is **not** configured in ADFS, but in the Superset menus (Data → Databases, Security → …).

## OAuth / OIDC (files in the repository)

| File | Purpose |
|------|---------|
| `requirements-local.txt` | `authlib` — pulled in by the Superset image entrypoint at start |
| `pythonpath/custom_sso_security_manager.py` | Parse JWT from `access_token`, map claims → user and `role_keys` |
| `pythonpath/superset_config.py` | `OAUTH_PROVIDERS`, `AUTH_ROLES_MAPPING`, `SUPERSET_AUTH_TYPE` switch |
| `ca-certificates.crt` | Bundle for TLS to ADFS inside the container (do not commit) |
| `docker-compose.yml` | `extra_hosts` for ADFS, mounts for CA and `requirements-local.txt` |

## First start (migrations and admin)

The **`superset-init`** service is in the **`init` profile** so a regular `docker compose up -d` does not re-run admin creation and does not fail on repeat.

From the directory with `docker-compose.yml`:

```bash
docker compose up -d db redis
docker compose --profile init run --rm superset-init
docker compose up -d
```

A repeat run with the init profile after admin already exists fails on user creation — initialize only against an empty database.

## Day-to-day operation

```bash
docker compose up -d
docker compose pull   # when the tag in .env changes
```

## Nginx

```bash
cd nginx
docker compose up -d
```

Confirm that DNS `superset.example.com` points at this VM and that 443 is reachable from the load balancer / firewall (and 80 for redirect when needed).

## Upgrading the Superset version

Set a new `SUPERSET_IMAGE` tag in `.env`, then:

```bash
docker compose pull
docker compose run --rm superset superset db upgrade
docker compose up -d
```

Do not re-run `superset-init` with the init profile on upgrade (that path does a full `superset init` and admin creation).

## Backup

For a state snapshot, copy **`./data/postgres`**, **`./data/redis`**, **`./data/superset_home`** (with containers stopped or via volume snapshots — per the operations policy).

## Links

- [Docker Compose (official)](https://superset.apache.org/docs/installation/docker-compose/)
- [Configuration](https://superset.apache.org/docs/configuration/configuring-superset/)

## LDAP

Not used separately: login is **OIDC to ADFS** (see above).
