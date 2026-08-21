# Werf retail (multi-stage + scan gates)

**Business first:** one build, named stands, a scan before promote, and a release that is a trigger, not a Friday `werf converge`. Buyer page: [`../../../../docs/for-business.md`](../../../../docs/for-business.md). Hub: [`../../`](../../).

I used this tree as a **werf common-ci include library** for a shop that already had `werf.yaml` and `.helm/`. The job is the shared GitLab include: `werf build`, env deploys (dev through pilot, then production plus reserve and two tenants), review, ReleaseCI, BI child-pipeline fan-out, Trivy filesystem scan, Grype image scan, and Sonar Java / .NET. Not host bootstrap. Review / canary without these scan gates lives in the sibling ([`../werf-delivery/`](../werf-delivery/)).

Brand, live GitLab / registry hosts, tenant names, Cloudflare zone IDs, and runner tags that identified a company are stripped. Job bodies stay so a reviewer can parse a real common-ci, not a three-job demo. Charts and `werf.yaml` stay with the app. Sanitize: [`../../SANITIZE.md`](../../SANITIZE.md).

```text
werf-retail/
  common.yml.example                 # werf base, stages, dual-cluster contexts, tenant tag hook
  cleanup.yml.example                # scheduled werf cr login + werf cleanup
  security-scan.yml.example          # Trivy fs + GitLab SAST / secret-detection + Grype
  sonarqube.yml.example              # Java CLI + .NET msbuild (this dialect)
  unitTests.yml.example              # .NET + cobertura / trx
  multiStageMain.yml.example         # Ready to Prod / Start Release triggers
  multiStageMainCommon.yml.example   # Build + env deploys (dev…pilot)
  multiStageMainOld.yml.example      # production + reserve + tenant-a/b
  multiStageInfra.yml.example
  multiStageInfraInputs.yml.example  # GitLab CI inputs: plan/deploy per env
  release-manager.yml.example        # generated child pipeline from config.yaml
  reviewStep.yml.example             # older review include (pulls common.yml)
  reviewDeployToExisted.yml.example
  sentry.yml.example
  snippets.yml.example
  publishPackage.yml.example         # nuget push via werf kube-run
  uploadStaticToS3.yaml.example
  user-migrations.yaml.example
  varReplicas.yml.example
  CFSSRCacheClean.yml.example
  BI-MultiDeploy.yml.example         # includes the one env file
  BI-MultiDeploy/
    multideploy-env.yml.example      # the one env (demo graph)
  review/
    main.yml.example
    main-vars.yml.example
    infra.yml.example
  ReleaseCI/
    create_release.yml.example
    ready_to_prod.yml.example
    release_web_ui.yml.example
    CF_SSR_clean_cache.yml.example
    upload_static_to_s3.yml.example
  rules/rules.yml.example
  scripts/purge_ssr_cache.sh
```

This folder is catalog YAML (`*.yml.example` / `*.yaml.example`). A consumer copies the needed files to live names in a private app repo, or includes the `.example` paths as-is in a lab project. Local `include:` paths in this tree already point at the `.example` names.

Scan gates stay in this kit. They are not folded into [`../security-gates/`](../security-gates/). The Java / Gradle Sonar include is a different dialect ([`../java-gradle/jobs/test/sonarqube.yml.example`](../java-gradle/jobs/test/sonarqube.yml.example)). The SonarQube **service** chart is [`../../../helm/reference/helm-addons-extra/sonarqube/`](../../../helm/reference/helm-addons-extra/sonarqube/). Scanner images referenced here live under [`../../../docker/images/`](../../../docker/images/). Dockerfiles stay in that tree, not here.

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| `multiStageMainCommon.yml.example` | One Build, then manual or auto deploys to dev, test-e, testdb, sales, stage, demo, pilot. Rules skip schedule / trigger / release types. |
| `multiStageMain.yml.example` | Ready to Prod and Start Release are child pipelines. Bodies are `ReleaseCI/*.yml.example` in this tree. |
| `multiStageMainOld.yml.example` | Production, reserve cluster, tenant-a / tenant-b. Dual kube-context swap lives in `common.yml.example`. |
| `security-scan.yml.example` | Real Trivy `fs` job (cache, DB download, GitLab `gitlab.tpl` artifact, fail on CRITICAL) plus Grype image loop. GitLab SAST / secret-detection templates. |
| `sonarqube.yml.example` | Java `sonar-scanner` CLI and `dotnet-sonarscanner` begin/build/end. MR and branch jobs. Included from `multiStageMainCommon.yml.example`. |
| `cleanup.yml.example` | Scheduled `werf cr login` + `werf cleanup --keep-stages-built-within-last-n-hours=24`. |
| `review/main.yml.example` | Review hub: converge, HAProxy / Envoy / ingress / Rabbit / Redis / ClickHouse child pipelines, smoke tests. |
| `release-manager.yml.example` | `yq` builds a child pipeline from app-repo `config.yaml`, then smoke / Locust triggers. |
| `BI-MultiDeploy/` | One env kept (demo graph). Sibling env clones are the same jobs with different namespace / stage. |
| `scripts/purge_ssr_cache.sh` | Cloudflare cache-tag purge. Zone IDs are `CHANGE_ME_*`. |

```bash
# example: compose the multi-stage hub in a lab project (GitLab project root = this folder)
# include:
#   - local: '/multiStageMain.yml.example'
```

`review/main.yml.example` and `review/infra.yml.example` extend `.base_werf` from `common.yml.example` but do not include it. Compose them with `common.yml.example`. `reviewStep.yml.example` already includes `common.yml.example`.

## Honest gaps

- No OSV-Scanner job. None was in the source tree. None was written.
- No `werf.yaml` and no Helm charts. `werf converge` cannot be exercised from this folder alone. App-repo hooks (`.sentry.helper.sh`, `werf_pre_converge_script.sh`, `config.yaml` for release-manager) stay with the app.
- `multiStageMain.yml.example` still triggers `project: shop-app/common-ci` `file: /ReleaseCI/*.yml.example`. Those files are in this tree. A lab consumer keeps that project path or switches the include to `local:`.
- Child `project:` paths (review HAProxy / Envoy / ingresses / Rabbit / Redis / ClickHouse, `shop-app/bi/*`, `shop-app/qa/smoke-tests`, `shop-app/qa/locust-tests`) are estate wiring. Those repos are not in this folder.
- GitLab.com templates `Jobs/Secret-Detection.gitlab-ci.yml` and `Jobs/SAST.gitlab-ci.yml` are upstream, not in this tree.
- BI hub includes one env file. Sibling env names (dev, test-e, testdb, sales, stage, production, production-reserve-b, tenant-b) stay in a comment on `BI-MultiDeploy.yml.example`.
- Trivy / Grype / sonar-scanner images are `example.registry/shop-app/base-images/…`. Dockerfiles stay under [`../../../docker/images/`](../../../docker/images/).
- `snippets.yml.example` `dump_env` prints the full environment. Shape is useful; a live run leaks CI variables.
- Review destroy / dismiss jobs delete namespaces, Gateway API objects, and Helm releases. Dangerous on a shared cluster without renaming filters.
- Historic secret detection (`SECRET_DETECTION_HISTORIC_SCAN: "true"`) is source-faithful and expensive.

**Keywords:** werf, GitLab CI, Trivy, Grype, SonarQube, SAST, review environment, release, BI, Cloudflare, S3, Sentry, NuGet
