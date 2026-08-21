# Knowledge-base example CI (werf converge)

**Business first:** a teaching repo can **converge a namespace from GitLab** without a shared include farm. Sanitize: [`../../SANITIZE.md`](../../SANITIZE.md).

I keep this file as one self-contained werf teaching pipeline. Borg, Deckhouse authz, and Redis operator already ship CI next to their charts. This PHP-shaped example still teaches `werf converge` plus a registry pull-secret copy into the review namespace.

```text
kb-example-ci/
  .gitlab-ci.yml.example    # multiwerf + werf ci-env + converge to test / production
```

Chart teaching trees (no PHP chart in that kit): [`../../../helm/reference/helm-kb-examples/`](../../../helm/reference/helm-kb-examples/).  
Retail / delivery werf graphs live in sibling pipeline folders, not here.

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| `.base_werf` YAML anchor | `multiwerf use` then `werf ci-env gitlab` before every converge |
| Namespace + pull secret | Create `${CI_PROJECT_NAME}-${CI_ENVIRONMENT_SLUG}` and copy `registrysecret` from `kube-system` |
| Two environments | Manual test on branches. Manual production on `master` |
| `except: schedules` | Teaching file does not run on cron |

## Honest gaps

- No `werf.yaml` and no PHP chart in this folder. The pipeline is the lesson, not a product tree.
- Runner tag stays `werf` (this teaching file). Other kits in this catalog may pin `docker`.
- Production job uses `master`, not `main`.
- Shared `infra/pipeline` includes used by thinner teaching clones are not in this catalog. This file does not need them.

**Keywords:** GitLab CI, werf, converge, multiwerf, teaching pipeline
