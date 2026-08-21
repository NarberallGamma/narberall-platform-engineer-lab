# Java / Gradle service pipelines

**Business first:** a service repo includes one hub and gets test, deploy, backup, and AppSec stages without copying fifty job files.

I used this include tree for JVM services and a few sibling runtimes. The GitLab project root is this folder (or a copy of it next to the service). Hubs pull common, test, deploy, e2e, backup, and security jobs. Kaniko / Helm / Maven **build** job files are not in this tree. Those include lines stay commented so a copied hub still loads.

Hunter map: [`../`](../). CI hub: [`../../README.md`](../../README.md). Image build context: [`../../../docker/images/apps/java-gradle/`](../../../docker/images/apps/java-gradle/). Kaniko pin: [`../../../docker/images/ci/kaniko/`](../../../docker/images/ci/kaniko/). Sanitize: [`../../SANITIZE.md`](../../SANITIZE.md).

```text
java-gradle/
  base.yml.example              # generic (non-Gradle) hub + child security pipeline
  base.gradle.yml.example
  base.js.yml.example
  base.python.yml.example
  base.docker.yml.example
  jobs/common/                  # Vault dotenv, Kaniko registry login
  jobs/test/                    # Sonar, Allure, Gradle integration, Postman / Kaniko --no-push
  jobs/deploy/                  # one Helm upgrade to dev
  jobs/e2e/                     # Playwright + Allure (JS hub)
  jobs/backup/                  # one dump, one restore
  jobs/security/                # modular AppSec + monolithic twin + ZAP plan
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Five hubs | Same estate, different runtime: generic, Gradle, Node, Python, image-only |
| `jobs/test/` | Sonar on class files, Gradle integration on MR to `dev`/`develop`, Allure upload, a Kaniko `--no-push` image gate named `test` |
| `jobs/deploy/deploy-dev.yaml.example` | Manual Helm upgrade with kube token from CI variables. One stand, not a clone per hostname |
| `jobs/e2e/run-e2e.yaml.example` | Playwright against `$E2E_TEST_BASE_URL`, domain parsed into `$E2E_TEST_DOMAIN`, Allure server upload |
| `jobs/backup/` | Vault AppRole into dotenv, `pg_dump` / restore against a test DB, object-store put/get |
| `jobs/security/` | One file per tool (Semgrep, PII, DeepSecrets, CycloneDX, Dependency-Track, DefectDojo) plus a monolithic hub that also runs ZAP |

```bash
# attach a hub from a service repo (GitLab project root = this folder)
# include:
#   - local: base.gradle.yml.example
```

Do not include `jobs/security/base-security.yml.example` and `jobs/security/base-appsec.yml.example` in the same pipeline. They both define DefectDojo / Semgrep / CycloneDX jobs.

## Honest gaps

- `jobs/build/*` (`build.yml`, `build.gradle.yml`, `build.js.yml`, `build.helm.yml`, `build-manual.yml`, `maven-publish.yml`) are not in this tree. Hub includes for those files stay commented. No synthetic Kaniko / Helm / Maven jobs were written.
- `jobs/test/test.yml.example` and `jobs/test/sonarqube.yml.example` `needs:` `gradle build` and `build-manual`, which live in the missing build files. Those needs stay optional or will wait until the build jobs exist.
- `jobs/test/sonarqube-java.yml.example` is on disk but not listed in any hub `include:`.
- `jobs/e2e/run-e2e.yaml.example` is included only from `base.js.yml.example`, not from the Gradle hub.
- No OSV-Scanner job. No Trivy job in this tree.
- Charts under `.helm/` are a runtime path, not published here.

Brand, live GitLab URLs, people allowlists, and Vault mount names are stripped. Job bodies (stages, rules, scripts, artifacts) stay so a reviewer can parse a real service pipeline, not a three-job demo.
