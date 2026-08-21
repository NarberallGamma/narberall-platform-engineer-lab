# PHP RoadRunner compose

**Business first:** RoadRunner is `rr serve` on a **bind-mounted app tree**, not a baked-only image. Image: [`../../images/apps/php-roadrunner/`](../../images/apps/php-roadrunner/). Sanitize: [`../../SANITIZE.md`](../../SANITIZE.md).

```text
php-roadrunner/
  docker-compose.yml   # cli + app, rr serve -d -c .rr.yml, :8200→3000
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| `build.dockerfile: docker/Dockerfile` | Original app-tree path. Lab Dockerfile lives under `images/apps/php-roadrunner/` |
| `command: rr serve` | Same binary the image copies from `spiralscout/roadrunner` |
| `./:/app` | Dev bind mount on both cli and app |

`.rr.yml` and the PHP tree are not in git. `docker compose up` fails until that context exists.

```bash
# place the omitted app next to docker/Dockerfile (or retarget build to the image kit)
docker compose up
```

**Keywords:** RoadRunner, docker compose, PHP 7.4
