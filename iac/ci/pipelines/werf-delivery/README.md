# Werf delivery (review, canary, cleanup)

**Business first:** a merge request gets a review namespace, a canary slice can ship beside prod, and leftover namespaces are a scheduled job. That is the delivery button, not a Friday `kubectl`. Buyer page: [`../../../../docs/for-business.md`](../../../../docs/for-business.md). Hub: [`../../`](../../).

I used this tree as a **werf common-ci include library**. Apps already had `werf.yaml` and `.helm/`. The job is delivery-shaped werf: `REVIEW-START` / `REVIEW-STOP`, `WERF_SET_CANARY`, Slack threads, and `werf cleanup` on a schedule. Not Trivy. Not SonarQube. Those gates live in the sibling retail kit ([`../werf-retail/`](../werf-retail/)).

Brand names, live GitLab hosts, and npm tokens are stripped. Job bodies stay intact so a reviewer can parse a real common-ci, not a three-job demo. Charts and `werf.yaml` stay with the app (lab samples: [`../../../helm/apps/werf-monorepo-sample/`](../../../helm/apps/werf-monorepo-sample/), [`../../../helm/apps/werf-raw/webapps/`](../../../helm/apps/werf-raw/webapps/)). Sanitize: [`../../SANITIZE.md`](../../SANITIZE.md).

```text
werf-delivery/
  common.yml.example              # hub: Build, Cleanup, converge, rules (werf 1.2 ea)
  notify-scripts.yml.example      # Slack thread notify
  review.yml.example              # REVIEW-START/STOP + stale review NS GC
  review-infra.yml.example        # optional infra release before REVIEW
  tests-front.yml.example         # Storybook / snapshots / lint / helm render
  nexus-publish.yml.example       # npm version bump + private registry publish
  backend/
    common.yml.example            # richest rules + Cleanup (werf 1.2 alpha)
    review.yml.example
    review-infra.yml.example
    deploy.yml.example            # the one generic deploy (preprod + production)
    plan.yml.example
    static.yml.example
    codecept.yml.example
    check-php-components.yml.example
  canary/
    common.yml.example            # canary-app hub (werf 1.2 stable)
    deploy-canary.yml.example     # WERF_SET_CANARY overlay
    deploy.yml.example            # canary-app env matrix
    plan.yml.example
  autotests/
    common.yml.example            # werf 2 ea + NELM
    notifications.yml.example
    autotests.yml.example         # Maven + Allure Docker Service + Selenoid
    triggers.yml.example          # multi-project e2e trigger
```

This folder is catalog YAML (`*.yml.example`). A consumer copies the needed files to live names in a private app repo, or includes the `.example` paths as-is in a lab project. One hub per pipeline. Overlays that have no `include:` of their own are composed with that hub:

- `review.yml.example` together with `review-infra.yml.example` (root `.base_review` lives in `review.yml.example`)
- `backend/review.yml.example` together with `backend/review-infra.yml.example`
- `canary/common.yml.example` together with `canary/deploy-canary.yml.example`
- `autotests/common.yml.example` together with `autotests/triggers.yml.example`

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| `canary/deploy-canary.yml.example` | `WERF_SET_CANARY=canary.enabled=true` on dev / preprod / prod, one replica, Postgres off. Plan and deploy jobs. |
| `review.yml.example` | MR `REVIEW-START` / `REVIEW-STOP`, `auto_stop_in: 3 days`, scheduled stale-namespace GC. |
| `Cleanup` on each hub | `werf cr login` + `werf cleanup` on schedule. Review and Codecept also sweep empty NS. |
| `notify-scripts.yml.example` | Slack thread: pipeline start, build, deploy URL list. Token is a CI variable. |
| `backend/check-php-components.yml.example` | PHPStan, php-cs-fixer, Pest + Cobertura, Composer package publish on tag. |
| `backend/codecept.yml.example` | Ephemeral Codecept NS, logs artefact, delete NS after the run. |
| `autotests/` | Maven Surefire, Allure Docker Service, Selenoid hub, multi-project trigger. |
| Four werf pins | Root `1.2 ea`, backend `1.2 alpha`, canary `1.2 stable`, autotests `2 ea`. trdl + `werf ci-env gitlab`. |
| `partner-a` / `partner-b` rules | Franchise lane model (sanitized names). Extra brand-only deploy files stay out. |

```bash
# example: compose root review + optional infra in a lab project
# include:
#   - local: review.yml.example
#   - local: review-infra.yml.example
```

## Honest gaps

- No Trivy, no SonarQube, no OSV in this tree. Scan gates are the sibling retail kit, not invented here.
- No `werf.yaml` and no Helm charts. `werf converge` / `grep project` cannot be exercised from this folder alone.
- Root `review-infra.yml.example` extends `.base_review` but includes only `common.yml.example`. Alone it fails GitLab validation.
- `canary/deploy-canary.yml.example` and `backend/review-infra.yml.example` have no `include:`. Those overlays are composed with their hub.
- Root `common.yml.example` keeps `WERF_NELM=0` under `variables:` as published (invalid-looking GitLab YAML).
- `canary/plan.yml.example` repeats the Production plan job. Left as published.
- `autotests/triggers.yml.example` points at `project: autotests/shop-app-e2e` (remote until that project exists).
- npm auth in `nexus-publish.yml.example` is `CHANGE_ME`. That job is shape-only from this tree.
- Review / Codecept cleanup greps namespaces by app name and deletes Helm releases. Dangerous on a shared cluster without renaming filters.

**Keywords:** werf, GitLab CI, canary, review environment, cleanup, Slack, PHP, PHPStan, Codecept, Maven, Allure, Selenoid
