# Docker images

**Business first:** CI builds **one richest image per mechanic**, then the registry is the hand-off. Buyer page: [`../../../docs/for-business.md`](../../../docs/for-business.md). Case: [`../../../case-studies/12-docker-images.md`](../../../case-studies/12-docker-images.md). Hub: [`../`](../).

I publish pins, runners, estate operators, and product packaging here. Pipelines that call `docker build` stay in [`../../ci/`](../../ci/). Helm after the push stays in [`../../helm/`](../../helm/). Compose that consumes an image stays in [`../compose/`](../compose/).

Honest scope: one mechanic per folder. This is not a dump of a hundred shop Dockerfiles. App source, Postman collections, JARs, and the CloudEye Go tree stay out. The listed folders are on disk.

```text
images/
  ci/
    kaniko/
    ansible-ee/
    base-runner-k8s/
    base-runner-docker/
    jvm-base/
    liberica-jre/
    node-20-alpine/
    node-22-alpine/
    node-e2e-ci/
    helmfile/
    maven/
  operators/
    cert-orchestrator/       # image + compose + env/config
    cert-monitoring/
    hibernate/
    cloud-metrics/           # Dockerfile only; src/ stays out
    cloud-status/
    static-nginx/
    edr-coverage/            # vendor-edr.py (renamed)
  apps/
    java-gradle/
    java-runtime-split/
    node-frontend/           # the one .npmrc
    node-nginx-spa/
    e2e/
    e2e-envfile/
    vitest/                  # share ../node-frontend/.npmrc
    newman/
    nifi/
    keycloak/
    superset/
    jsm/
    python-agent/
    python-service/
    ships-api/
    ships-bridge/
    php-fpm/
    php-ci/
    nginx-php/
    node-vite/
    composer/
    php-fpm-legacy/
    php-api/
    php-oms/
    poetry-admin/
    poetry-fix-donor/
    poetry-fix-slot/
    dashy/
    go-wine-bridge/
    php-octane/
    php-roadrunner/
    node-private-npm/
    ovpn-admin/
    nginx-limit-upstream/
    libvirt-guest/
```

## Who this page is for

| Reader | What to take | Then open |
|--------|----------------|-----------|
| Hiring lead | Pins are honest retags. Two Java images cover a shop. Two runners are different mechanics. | Table below, [case 12](../../../case-studies/12-docker-images.md) |
| Engineer | Build from the kit folder. Each README says the missing context (app tree, JAR, CloudEye src). | Kit table |
| Founder / PM | The pipeline builds here. Argo or Compose is the next page. | [`../../ci/`](../../ci/), [`../../helm/`](../../helm/), [`../compose/`](../compose/) |

## On disk

Folders that already have a `Dockerfile*` when this page was written:

| Class | Living folders |
|-------|----------------|
| `ci/` | `kaniko`, `ansible-ee`, `base-runner-k8s`, `base-runner-docker`, `jvm-base`, `liberica-jre`, `node-20-alpine`, `node-22-alpine`, `node-e2e-ci`, `helmfile`, `maven` |
| `operators/` | `cert-orchestrator` (image + compose), `cert-monitoring`, `hibernate`, `cloud-metrics`, `cloud-status`, `static-nginx`, `edr-coverage` (`vendor-edr.py`) |
| `apps/` | `java-gradle`, `java-runtime-split` (`Dockerfile` + `Dockerfile.runtime`), `node-frontend` (`.npmrc`), `node-nginx-spa`, `e2e`, `e2e-envfile`, `vitest` (shares the frontend `.npmrc`), `newman`, `nifi`, `keycloak`, `superset`, `jsm`, `python-agent`, `python-service`, `ships-api`, `ships-bridge`, `php-fpm`, `php-ci` (plus `tests/Dockerfile`), `nginx-php`, `node-vite` (`Dockerfile` + `Dockerfile.watch`), `composer`, `php-fpm-legacy` (plus nested `composer/Dockerfile`), `php-api`, `php-oms`, `poetry-admin`, `poetry-fix-donor`, `poetry-fix-slot`, `dashy`, `go-wine-bridge` (three Dockerfiles), `php-octane`, `php-roadrunner`, `node-private-npm`, `ovpn-admin` (`Dockerfile.ovpn-admin`), `nginx-limit-upstream`, `libvirt-guest` |

## CI pins and runners

| Slice | Mechanic | Why one copy is enough |
|-------|----------|------------------------|
| [`ci/kaniko/`](ci/kaniko/) | One-line Kaniko debug retag | In-cluster build without a Docker daemon. One pin is enough |
| [`ci/ansible-ee/`](ci/ansible-ee/) | Alpine 3.20, ansible-core 2.16.x, `hvac`, `community.hashi_vault` | Vault lookup on the job. Lab [`../../ansible/reference/ansible-runner/`](../../ansible/reference/ansible-runner/) stays the unpinned host wrapper |
| [`ci/base-runner-k8s/`](ci/base-runner-k8s/) | kubectl, Helm, token kubeconfig, `regcred` script | Kubernetes-backed runner |
| [`ci/base-runner-docker/`](ci/base-runner-docker/) | Alpine + Docker **client** 26.1.1 + `docker login` | Different mechanic. Daemon is the job service |
| [`ci/jvm-base/`](ci/jvm-base/) | `FROM eclipse-temurin:11-jre` | Honest Java 11 pin |
| [`ci/liberica-jre/`](ci/liberica-jre/) | Bellsoft Liberica 21 musl + CA + tzdata | Java 21 CI/runtime parent. Not a one-line retag |
| [`ci/node-20-alpine/`](ci/node-20-alpine/) | `FROM node:20-alpine` | Honest Node 20 pin |
| [`ci/node-22-alpine/`](ci/node-22-alpine/) | `FROM node:22-alpine` | Honest Node 22 pin |
| [`ci/node-e2e-ci/`](ci/node-e2e-ci/) | Node 22 + Chromium + fonts | Browser tests without apt-get on every job |
| [`ci/helmfile/`](ci/helmfile/) | `alpine/helm` + helmfile + helm-diff; optional kubectl | Two tags from one file. Kit carries a thin `.gitlab-ci.yml` |
| [`ci/maven/`](ci/maven/) | Node host + OpenJDK 17 + Maven + Docker client | `DOCKER_HOST=tcp://docker:2375`. Not a Maven official image |

## Operators

| Slice | Mechanic | Why one copy is enough |
|-------|----------|------------------------|
| [`operators/cert-orchestrator/`](operators/cert-orchestrator/) | DNS-01 wildcard, Kubernetes TLS secrets, SSH nginx reload, schedule | Image + compose + `.env.example` + `example-config.yaml` in one folder |
| [`operators/cert-monitoring/`](operators/cert-monitoring/) | Long-running SSL expiry watch + Telegram | Ansible estate deploys the same slug |
| [`operators/hibernate/`](operators/hibernate/) | Night-park stop/start on CCE workers and ECS | FinOps proof next to Terraform sketch and estate Ansible |
| [`operators/cloud-metrics/`](operators/cloud-metrics/) | CloudEye exporter **Dockerfile only** | `src/` is the upstream Go tree. Not copied. Overlay consumes the image |
| [`operators/cloud-status/`](operators/cloud-status/) | Cloud.ru status `/metrics` | Owner HTTP client is in git |
| [`operators/static-nginx/`](operators/static-nginx/) | Ubuntu + nginx static site | Corporate landing, not a shop SPA |
| [`operators/edr-coverage/`](operators/edr-coverage/) | AD + cloud inventory + vendor EDR → Prometheus | Collector is `vendor-edr.py`. Host compose pins the image |

## App mechanics

| Slice | Mechanic | Why one copy is enough |
|-------|----------|------------------------|
| [`apps/java-gradle/`](apps/java-gradle/) | Gradle 9 + Temurin 21, combined multi-stage, JDWP | One file covered a dozen backends. Gradle tree is not in git |
| [`apps/java-runtime-split/`](apps/java-runtime-split/) | Gradle 8 build vs Liberica `Dockerfile.runtime` | CI can compile on the runner. JAR / JKS stay out |
| [`apps/node-frontend/`](apps/node-frontend/) | Four-stage Next standalone + the **one** `.npmrc` | Private `@shop-app` scope is `CHANGE_ME` |
| [`apps/node-nginx-spa/`](apps/node-nginx-spa/) | Node 20 build → nginx + `envsubst` `config.js` | Not a second Next image |
| [`apps/e2e/`](apps/e2e/) | Playwright, accounts as `ENV` | Chromium from apk. Test tree stays out |
| [`apps/e2e-envfile/`](apps/e2e-envfile/) | Playwright, `.env.e2e.<stand>`, ARG after `FROM` | Different mechanic from `e2e/` |
| [`apps/vitest/`](apps/vitest/) | Node 22 unit-test image | **Share** [`apps/node-frontend/.npmrc`](apps/node-frontend/.npmrc). No second copy |
| [`apps/newman/`](apps/newman/) | Newman runs the collection at build | Collection JSON stays out |
| [`apps/nifi/`](apps/nifi/) | NiFi packaging image | Living tree in that folder |
| [`apps/keycloak/`](apps/keycloak/) | Keycloak packaging image | Living tree. Cluster overlay is Helm |
| [`apps/superset/`](apps/superset/) | Superset packaging image | Living tree in that folder |
| [`apps/jsm/`](apps/jsm/) | JSM packaging image | Living tree in that folder |
| [`apps/python-agent/`](apps/python-agent/) | Python agent packaging | Living tree in that folder |
| [`apps/python-service/`](apps/python-service/) | Python 3.12 slim service | `requirements.txt`. App entry is not in git |
| [`apps/ships-api/`](apps/ships-api/) | Ships HTTP API image | Sibling of ships-bridge |
| [`apps/ships-bridge/`](apps/ships-bridge/) | Ships bridge image | Sibling of ships-api |
| [`apps/php-fpm/`](apps/php-fpm/) | PHP-FPM | Living tree in that folder |
| [`apps/php-ci/`](apps/php-ci/) | PHP CI image | Plus `tests/Dockerfile` |
| [`apps/nginx-php/`](apps/nginx-php/) | nginx in front of PHP | Living tree in that folder |
| [`apps/node-vite/`](apps/node-vite/) | Vite front image | `Dockerfile` + `Dockerfile.watch` |
| [`apps/composer/`](apps/composer/) | Composer image | One `composer.sh` |
| [`apps/php-fpm-legacy/`](apps/php-fpm-legacy/) | Legacy PHP-FPM | Nested composer Dockerfile |
| [`apps/php-api/`](apps/php-api/) | PHP API | Living tree in that folder |
| [`apps/php-oms/`](apps/php-oms/) | PHP OMS | Living tree in that folder |
| [`apps/poetry-admin/`](apps/poetry-admin/) | Poetry admin | Pattern set with donor / slot |
| [`apps/poetry-fix-donor/`](apps/poetry-fix-donor/) | Poetry donor | Pattern set with slot |
| [`apps/poetry-fix-slot/`](apps/poetry-fix-slot/) | Poetry slot | Pattern set with donor |
| [`apps/dashy/`](apps/dashy/) | Dashy dashboard | Config + launcher in the image |
| [`apps/go-wine-bridge/`](apps/go-wine-bridge/) | Go + Wine bridge | Three Dockerfiles in one folder |
| [`apps/php-octane/`](apps/php-octane/) | Swoole / Octane | Contrast with RoadRunner |
| [`apps/php-roadrunner/`](apps/php-roadrunner/) | RoadRunner | Contrast with Octane |
| [`apps/node-private-npm/`](apps/node-private-npm/) | Private npm feed | Living tree in that folder |
| [`apps/ovpn-admin/`](apps/ovpn-admin/) | OpenVPN admin image | `Dockerfile.ovpn-admin`. Compose sibling under `compose/ovpn-admin/` |
| [`apps/nginx-limit-upstream/`](apps/nginx-limit-upstream/) | nginx limit + upstream | Living tree in that folder |
| [`apps/libvirt-guest/`](apps/libvirt-guest/) | libvirt guest builder | Living tree in that folder |

## What this folder is not

- Not a dump of every client Dockerfile. One richest file per mechanic. A hundred-plus identical shop clones stay private
- Not application source, collections, JARs, or vendor binaries. Kit READMEs say when `docker build` needs that tree
- Not the CI YAML catalog. Pipelines stay under [`../../ci/`](../../ci/)

**Keywords:** Docker, Dockerfile, Kaniko, ansible-ee, Helm, Maven, Liberica, Next.js, Playwright, Newman, PHP, Poetry, Keycloak, NiFi, CloudEye, EDR, night-park
