# Dashy estate panel

**Business first:** the internal link panel is a **baked Dashy config**, not a wiki bookmark list. Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).

I used the official `lissy93/dashy` image and copied a full production/dev section map into `/app/user-data/conf.yml`. Hostnames and API keys in this tree are `*.example.com` / `CHANGE_ME`. The lowercase `dockerfile` from the source tree is published here as `Dockerfile`.

```text
dashy/
  Dockerfile   # FROM lissy93/dashy:latest, COPY config + launcher
  config.yml   # prod/dev sections (generic hosts)
  script.sh    # host-style docker run (published ENTRYPOINT)
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Baked `config.yml` | Estate map (GitLab, Grafana, Kafka UI, VPN admin) travels with the image |
| `script.sh` as ENTRYPOINT | Original launcher is a `docker run` of upstream Dashy, not a process exec. Odd, kept |
| Rename | Source file was `dockerfile`; lab name is `Dockerfile` |

This image **can** build. The container then runs `script.sh`, which expects a Docker socket and a host `config.yml`. That is the published quirk, not a rewrite.

```bash
docker build -t example.registry/dashy:local -f Dockerfile .
docker run --rm -p 4000:4000 example.registry/dashy:local
# expect the launcher to call docker run against lissy93/dashy:latest
```

**Keywords:** Dashy, estate links, baked config
