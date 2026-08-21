# Shop UI + API tests (Allure)

**Business first:** a stand is not done when Helm is green. **UI and Newman** run, zip Allure results, and upload to an Allure Server so a reviewer opens a report URL, not a zip on a laptop.

I used this as the one shop **test** pipeline I still have as a full job body. It is not `include:` of a shared Gradle base. Gradle plus Selenium covers UI. Newman covers API. Both jobs post to Allure and treat a failed generate as a failed job.

Hunter map: [`../../`](../../). Stand that those tests hit: [`../review-stand/`](../review-stand/). Shared Allure include in the Java/Gradle kit (different shape): [`../java-gradle/jobs/test/run_tests_and_publish_allure.yml.example`](../java-gradle/jobs/test/run_tests_and_publish_allure.yml.example). Newman image context: [`../../../docker/images/apps/newman/`](../../../docker/images/apps/newman/).

```text
shop-test-allure/
  .gitlab-ci.yml.example    # UI (Gradle + Chrome) + Newman API + Allure upload
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| `workflow.name` | Allure UI results URL (`allure.dev.example.com`). |
| UI job | `gradle:8.8.0-jdk17` + `selenium/standalone-chrome`. Stand must be `dev` / `test` / `demo`. `gradle test \|\| true`, then zip `build/allure-results` and POST `/api/result` + `/api/report`. |
| API job | `postman/newman`, `newman-reporter-allure`, manual, same Allure pair. `API_BASE_URL` is `https://test.example.com`. |
| Upload | `curl --resolve` pins the Allure host to a lab RFC1918 address (`10.10.6.20`). Report path is `auto-ui/<stand>` or `auto-api/test`. |
| Failure policy | Both jobs `allow_failure: true` and `timeout: 2h`. Report generate uses `-f` and exits 1 on curl failure. |

```bash
# to run as a live GitLab project: copy .gitlab-ci.yml.example to .gitlab-ci.yml
# place Gradle tests, flow.postman_collection.json, and the environment file in the project
# point ALLURE host and --resolve at the local Allure Server
```

## Honest gaps

- Gradle tests, Postman collections, and environment JSON are **not** in this folder.
- This is not a thin service include of `base.gradle.yml`. That shared hub lives in the Java/Gradle kit; this file is a standalone test pipeline.
- Allure host, API host, and `--resolve` address are placeholders. Replace before a real run.
- UI job continues after `gradle test` failure (`|| true`) and still tries the upload. That policy is kept as originally written.
- No OSV job. No invented Gradle base.

## Keywords

GitLab CI, Allure, Gradle, Selenium, Newman, Postman, UI test, API test
