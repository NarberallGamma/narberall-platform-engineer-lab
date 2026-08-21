# Postfix SMTP (host Compose)

**Business first:** outbound mail is a **boky/postfix container with public DNS**, not the estate resolver. Hub: [`../../../`](../../../). Collab index: [`../`](../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).

I used this file when estate DNS broke delivery. The container resolves via `8.8.8.8` / `8.8.4.4`. DKIM and TLS keys bind from `/docker/SSL_certs/smtp.example.com/`. Submission is `:587`. `SMTP_USERS` stays in env.

```text
postfix/
  docker-compose.yml    # boky/postfix, DKIM, TLS, public DNS
  .env.example          # SMTP_USERS (user:password pairs)
```

```bash
# from this directory, after DKIM keys, TLS PEM, and .env exist:
cp .env.example .env
docker compose up -d
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Public `dns:` | Mail does not depend on a broken internal resolver |
| DKIM + TLS from host PEM | Keys are not baked into the image |
| `RELAY_NETWORKS: 127.0.0.1/32` | Not an open relay |

## Honest gap

PEM, DKIM private keys, `./dkim`, `./init-scripts`, and a valued `.env` stay out of git. `DKIM_AUTOGENERATE` is `"false"`.

**Keywords:** Postfix, DKIM, SMTP submission, TLS
