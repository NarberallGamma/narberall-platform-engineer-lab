# Poetry admin API

**Business first:** a Flask admin service is a **Poetry lock plus a mode-switching entrypoint**, not a loose `pip install` on the host. Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md). Compose for Postgres and RabbitMQ: [`../../../compose/poetry-admin/`](../../../compose/poetry-admin/).

I used this image for the richest Poetry service in a market-data estate: Python 3.9, Poetry 1.1.12, seven local libraries, Flask/gunicorn, and one script that picks admin / Celery / Flask / consumer. Sibling images show the other two mechanics I kept: [`../poetry-fix-donor/`](../poetry-fix-donor/) (stunnel donor) and [`../poetry-fix-slot/`](../poetry-fix-slot/) (QuickFIX slot).

```text
poetry-admin/
  Dockerfile      # python:3.9, poetry install --no-dev, FLASK_APP
  entrypoint.sh   # admin | admin-celery | admin-flask | consume-events
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Poetry 1.1.12 installer | Lockfile install with `virtualenvs.create false`, cache wiped |
| Seven `libraries/` COPY lines | Shared market/db/slot SDKs, not a single-file app |
| `entrypoint.sh` cases | One image, four process shapes (gunicorn, Celery, Flask CLI, consumer) |

App source, `pyproject.toml`, `poetry.lock`, and the library trees are not in git. `docker build` fails until those paths exist next to the Dockerfile.

```bash
# from an app tree that has services/admin_api and libraries/
docker build -t example.registry/poetry-admin:local -f Dockerfile .
# after compose/poetry-admin is up:
# docker run --rm example.registry/poetry-admin:local admin
```

**Keywords:** Poetry, Flask, gunicorn, Celery, Python 3.9
