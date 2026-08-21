# EDR coverage exporter

**Business first:** "is the agent on every VM" is a metric, not a spreadsheet. I ran this image so AD + cloud inventory + the vendor EDR API merge into Prometheus gauges (port 9655) and a coverage report.

Host stack that pins the image: [`../../../../ansible/reference/ansible-llm-collab/extras/sec-stack/`](../../../../ansible/reference/ansible-llm-collab/extras/sec-stack/). Agent roll-out (package, not this exporter): [`../../../../ansible/reference/ansible-app-platform/`](../../../../ansible/reference/ansible-app-platform/). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).

```text
edr-coverage/
  Dockerfile              # python:3.12-slim, USER nobody, :9655
  edr_exporter.py         # background collect + /metrics
  merge3.py               # match engine
  vendor-edr.py           # vendor sensor API → *_edr.csv
  active-directory.py vkcloud.py sbercloud-adv.py edr_report.py
  tests/                  # match + AD assign, no live CSV
  .gitlab-ci.yml          # py_compile, pytest, kaniko
  *.example               # configs with CHANGE_ME
```

The collector file is `vendor-edr.py`.

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Four sources | LDAP, two cloud inventories, vendor EDR OAuth + cursor page. One collector crash leaves the others and the last CSV. |
| merge3 | Hostname / IP / os_hostname passes, aliases, exclusions. Tests cover rules that used to fail silently. |
| Scrape contract | Collect is a background loop (`EDR_COLLECT_INTERVAL`, default 6h). `/metrics` is the last snapshot, not a live LDAP hit. |
| CI | Lint compiles the same files the image `COPY`s. Kaniko pushes `CI_REGISTRY_IMAGE`. |

```bash
docker build -t example.registry/sec/edr-coverage:v0.7.2 .
docker run --rm -p 9655:9655 \
  -e EDR_DATA_DIR=/data \
  -e EDR_CONFIG_DIR=/config \
  -v /path/to/data:/data \
  -v /path/to/config:/config:ro \
  example.registry/sec/edr-coverage:v0.7.2
```

Copy `*.example` to the config dir (gitignored names). Tokens stay `CHANGE_ME`.

```bash
# from this directory
python -m pytest -q
```

## Honest gaps

- `uv.lock` is not published. Dockerfile uses `requirements.txt`. The CI job `uv sync --frozen` needs the lock on a private runner.
- Live AD / CSV / SOPS stay out. Examples and pytest fixtures are the published contract.
