# Locust (shop order / offer flow)

**Business first:** a shop load test is **master + worker and one sequential user**, not a screenshot of Locust’s empty UI. Kit: [`../`](../). Hub: [`../../../`](../../../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).

I used this pair when the shop needed a laptop soak of login → order → offer → close. The script reads `locust.env.example.json` (Postman-shaped keys). Live URLs and passwords stay out (`CHANGE_ME`, `shop.example.com`).

```text
locust/
  docker-compose.yml         # locustio/locust master :8089 + worker
  locustfile.py              # sequential shop HTTP tasks
  locust.env.example.json    # url + CHANGE_ME logins + fake UUIDs
```

```bash
# from this directory, after filling CHANGE_ME in locust.env.example.json
# and pointing url at a reachable shop API:
docker compose up
# UI: http://localhost:8089
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Master / worker | The real scale-out shape, not a single process |
| Sequential tasks | Client token, order UUID, operator login, offer, close |
| Example env JSON | Replaces a live Postman environment file |

## Honest gap

There is no shop API in this repo. Locust will start. The tasks fail until `url` and passwords point at a real stand. Fixture operator UUIDs are `00000000-0000-4000-8000-…`.

**Keywords:** Locust, master, worker, shop orders, load test
