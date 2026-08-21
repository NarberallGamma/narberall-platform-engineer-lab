# Poetry FIX slot

**Business first:** a FIX gateway slot is Poetry plus **`pip3 install quickfix`**, not another thin donor clone. Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md). Donor sibling: [`../poetry-fix-donor/`](../poetry-fix-donor/).

I kept this as the richest slot image: local `fix_*` libraries, Poetry install (dev deps left on), then QuickFIX from pip, then a single `python3` CMD.

```text
poetry-fix-slot/
  Dockerfile   # python:3.10, Poetry 1.1.12, pip3 install quickfix
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| `COPY ./libraries/fix_*` | Parser and trade-app libs next to the service |
| `pip3 install quickfix` | Native FIX binding on top of Poetry, not a second lockfile |
| `CMD` not ENTRYPOINT | One worker process, no stunnel |

`pyproject.toml`, lockfile, and library trees are not in git. `docker build` fails without them.

```bash
# needs services/fix_gateway and libraries/{logger,fix_trade_app,fix_parser,slot}
docker build -t example.registry/poetry-fix-slot:local -f Dockerfile .
```

**Keywords:** Poetry, QuickFIX, FIX gateway, Python 3.10
