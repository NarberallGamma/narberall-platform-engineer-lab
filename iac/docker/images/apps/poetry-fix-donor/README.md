# Poetry FIX donor

**Business first:** a FIX market-feed donor shares the Poetry skeleton and **adds stunnel in the same image**. Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md). Admin sibling: [`../poetry-admin/`](../poetry-admin/).

I used this when the vendor FIX session had to leave the box over TLS that the Python client did not terminate itself. The entrypoint writes stunnel configs, starts `stunnel4`, then runs the donor client.

```text
poetry-fix-donor/
  Dockerfile      # python:3.10, apt stunnel4, Poetry 1.1.12
  entrypoint.sh   # create_configs.py, copy stunnel files, start both
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| `apt install stunnel4` | TLS hop is a package in the image, not a sidecar guess |
| Poetry lock install | Same estate skeleton as admin and the FIX slot |
| Entrypoint order | Config generation, then stunnel, then `client.py` |

App source, lockfile, and stunnel PEMs are not in git. The image will not build or run as published.

```bash
# needs services/market_feed/{pyproject.toml,poetry.lock,entrypoint.sh}
docker build -t example.registry/poetry-fix-donor:local -f Dockerfile .
```

**Keywords:** Poetry, FIX, stunnel, Python 3.10
