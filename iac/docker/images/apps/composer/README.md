# Composer 2.3.5 helper (PHP 8.1)

**Business first:** `composer install` on the shop stand is its **own 8.1 container** with a pinned phar and a long-lived loop, not Composer on the FPM image. Hub: [`../../../`](../../../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md). FPM: [`../php-fpm/`](../php-fpm/). Legacy 7.4 helper: [`../php-fpm-legacy/`](../php-fpm-legacy/).

I used this sidecar next to the three FPM workers. The script installs, dumps the autoload, then `sleep 1000` so the container stays up. This folder is the **one** copy of `composer.sh`. The 7.4 Composer Dockerfile still `COPY`s that name. Place this file in that build context (same habit as vitest sharing [`../node-frontend/.npmrc`](../node-frontend/.npmrc)).

```text
composer/
  Dockerfile    # php:8.1-fpm-buster, git, gd+zip, Composer 2.3.5
  composer.sh   # install + dump-autoload --optimize + sleep 1000
```

```bash
# from this directory:
docker build -t example.registry/shop-app/composer:local .
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Composer **2.3.5** | Local pin. CI is **1.10.17** on [`../php-ci/`](../php-ci/). Legacy is **2.7.7** |
| `git` in the image | Some lockfiles need VCS dist |
| Long-lived `sleep` | Compose `up` keeps the helper, not a one-shot Job |
| One `composer.sh` | Byte-identical twin under the 7.4 tree was not copied |

## Honest gap

`composer.json` / `composer.lock` and the app tree are not in this folder. The container bind-mounts `/path/to/app`.

**Keywords:** Composer 2.3.5, PHP 8.1, dump-autoload, sidecar
