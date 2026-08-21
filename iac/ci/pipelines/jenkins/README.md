# Jenkins plus host backup CI

**Business first:** the deploy button on a Jenkins estate is one file: build the image, push it, then AWX launches the playbook. Backup freshness is the same habit on GitLab: validate the Borg job list, then install cron on the backup host.

I used this tree when workers were already labeled `docker` and when backup hosts needed a monitor that is not a wiki page. The include sample is a teaching stub. Shared `infra/common-ci` jobs are not in this folder.

Hunter map: [`../`](../). CI hub: [`../../README.md`](../../README.md). Host GitLab sibling: [`../host-lifecycle.gitlab-ci.yml.example`](../host-lifecycle.gitlab-ci.yml.example). Ansible those AWX jobs call: [`../../../ansible/`](../../../ansible/). GitHub Actions trio: [`../github-actions/`](../github-actions/). Sanitize: [`../../SANITIZE.md`](../../SANITIZE.md).

```text
jenkins/
  Jenkinsfile.example                         # docker.build → registry push → AWX curl
  include-sample.gitlab-ci.yml.example        # remote infra/common-ci (targets not here)
  backup-monitoring/
    backup-monitoring.gitlab-ci.yml.example   # validate then manual host deploy
    conf_schema.yml.example                   # pykwalify schema for the exception list
    conf/backup-staging.yaml.example          # generic exceptions only
    borg_jobs_monitoring.sh
    send_to_alerts.sh simple_alert.sh
    cron_deploy cron_template cron_template_dms
    become-message sudo-become-lecture-file
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| `Jenkinsfile.example` | Declarative pipeline: `docker.build` with a Git SSH build-arg, registry push, then `curl` to AWX with a microservice extra-var. Credential IDs are `CHANGE_ME`. Agent label is `docker`. |
| `include-sample.gitlab-ci.yml.example` | Remote `include:` of `infra/common-ci` `/deployInfra.yml` at `ref: v2`, plus two commented sibling files. Proves wiring. The include targets are not in this tree. |
| `backup-monitoring.gitlab-ci.yml.example` | `yamllint` + `pykwalify` on the exception list, then a manual job that copies scripts and installs cron on the backup runner. |
| `borg_jobs_monitoring.sh` | Full freshness, size, access, and disabled-backup checks against a per-project Borg layout. |
| Cron + alert helpers | Host install shape. Alert URL is `alerts.example.com`. Setup key is `CHANGE_ME`. |

```bash
# copy Jenkinsfile.example to Jenkinsfile in the service repo
# set credential IDs, registry, image tag, and branch on the controller
# GitLab include sample stays a stub until infra/common-ci exists
# backup-monitoring: GitLab project root = backup-monitoring/
```

Brand, live credential IDs, AWX URLs, and production Borg inventories are stripped. Job bodies stay so a reviewer can parse a real Jenkinsfile and a real backup monitor, not a three-line sketch.

## Honest gaps

- No Jenkins shared library (`@Library`, `vars/*.groovy`) exists in this tree. That library cannot be claimed.
- `infra/common-ci` files (`deployInfra.yml`, `deploy.yml`, `deployInfra1.2.yml`, and the two commented siblings) are not here. A copied include sample 404s until that project exists. The stub is the teaching point.
- The Jenkinsfile has no test, lint, scan, or revoke stages. Build, push, and AWX only.
- The build still passes an SSH private key as `GIT_SSH_PRIVATE_KEY` into `docker.build`. The credential ID is redacted. The shape is kept.
- The backup deploy job runs `printenv \| sort` on the runner.
- Live Borg job inventories stay out. Catalog conf is `backup-staging.yaml.example`. Jobs still name `backup-staging.yaml` and `backup-production.yaml` as live filenames.
- Schema path in the validate job points at `conf_schema.yml.example` so this catalog tree is consistent. A live project would drop `.example` from both the schema and the conf names.
- No OSV-Scanner job. No Trivy or SonarQube in this folder.
