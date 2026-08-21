# Release upgrade CI

Automation for a coordinated multi-repo release: first push of an upgrade branch creates an MR; a manual cutover pipeline approves and merges; an optional revert job rolls a past release back.

A consumer pipeline only includes `on-upgrade-branch-push.yaml.example`; that include stub is not published as its own kit.

`defaults.yaml.example` (image, registry, shared stages) lives in the estate common-ci hub, not in this folder.

## Files

| File | Role |
|------|------|
| `on-upgrade-branch-push.yaml.example` | include from the root of each helm repo |
| `release-cutover.yaml.example` | approve + merge (project `common-ci`) |
| `release-ansible-vm-deploy.yaml.example` | after merge: wait for ansible sync + manual docker-app deploy on the app VM |
| `release-revert.yaml.example` | revert a past release |
| `defaults-release.yaml.example` | variables, `.release_runner`, clone scripts |
| `scripts/*.sh` | GitLab API logic |
| `manifests/prod-release-repos.txt` | generic PROD repo list (`shop-app`, `estate-ansible`) |
| `manifests/preprod-release-repos.txt` | generic PREPROD repo list (`shop-app` only) |
| `manifests/prod-ansible-vm-apps.txt` | allowlist of ansible docker-apps for cutover deploy |

## Workflow

### A. Prepare (before the cutover window)

1. In each repo from `manifests/prod-release-repos.txt` (helm + **ansible**): create branch `upgrade/shop-app-X-estate-Y-prod`, edit values/playbooks, `git push -u origin upgrade/...`.
2. On the **first** push of that branch, job `release-mr-create` opens an MR to `main` and registers group vars `RELEASE_CURRENT_BRANCH` / `RELEASE_TITLE_PREFIX`.
3. Wait for green pipelines on the upgrade branches and review the MRs. The active branch is the group CI/CD variable (not to be edited by hand).

### B. Cutover day: one pipeline in `common-ci`

GitLab → project **`estate/common-ci`** → **CI/CD → Run pipeline** → branch **`main`**, source **web**. Extra variables are usually not required.

Jobs are numbered so the UI order matches `needs`:

| # | Job | Trigger | Action |
|---|-----|---------|--------|
| 1 | `release-01-preflight` | auto | print active branch and open MRs; `allow_failure` |
| 2 | `release-02-approve-all-mrs` | **Play** | approve every open MR of the active release |
| 3 | `release-03-merge-all-mrs` | **Play** | 60s countdown → merge all MRs to `main` (helm + ansible) |
| 4 | `release-04-wait-ansible-sync` | auto after merge | wait for a successful `estate/ansible` pipeline on `main` (rsync into `/ansible` on the runner). If an ansible MR was in this release, wait for the post-merge pipeline, not an older success |
| 5 | `release-05-deploy-ansible-vm` | **Play** | from the control node (`/ansible`): `run_docker_app.sh deploy` for apps in `manifests/prod-ansible-vm-apps.txt` |

Manual clicks: Play → approve → Play → merge → (wait for green) → Play → ansible VM deploy.

Approve and merge **must** run in the same pipeline (merge reads the approve artifact). A new Run without approve fails merge.

### C. After the cutover pipeline (outside release jobs)

1. **Argo CD:** wait for Synced on helm apps in the release → rollout restart of touched Deployments → smoke.
2. **Ansible VM** apps are already deployed by `release-05` when Play succeeded (no extra SSH + `run_docker_app.sh`).
3. If this release did **not** change app-VM docker-apps, skip `release-05` (wait still runs; deploy is optional).

### Ansible VM deploy

- Allowlist example: `shop-app` → host `host-01.example.com`.
- Single app: set `ANSIBLE_VM_APP=<slug>` on Run pipeline (or retry the job).
- New app later: add a line to `prod-ansible-vm-apps.txt` (`app_slug limit_host`) and push `common-ci` main.
- SSH keys: present under `/ansible/.ssh/` after the ansible sync job, or CI vars `ANSIBLE_SSH_PRIVATE_KEY_B64` / `GITLAB_RUNNER_SSH_PRIVATE_KEY_B64`.
- PREPROD: these jobs are **absent** (docker-apps there go through Kubernetes, not an ansible VM).

### Revert a past release

Separate chain in the same project (not the cutover `needs` graph):

- Run pipeline on `main`, variable **`REVERT_RELEASE_BRANCH`** = `upgrade/shop-app-1.0-estate-1.0-prod`
- Job **`release-revert-all-mrs`** (manual Play)
- Ansible VM rollback is a separate playbook (release-05 does not revert the VM)

## GitLab admin (required before the first run)

### 1. Group CI/CD variables (`estate`)

| Variable | Who sets it | Purpose |
|----------|-------------|---------|
| `RELEASE_BOT_TOKEN` | admin setup script | PAT `release-bot`, scope `api`, masked |
| `RELEASE_CURRENT_BRANCH` | **auto** (first push of an upgrade branch) | cutover approve/merge; do not edit by hand |
| `RELEASE_TITLE_PREFIX` | **auto** (from the branch name) | optional, for MR title |

On first push, for example `upgrade/shop-app-1.0-estate-1.0-preprod`, job `release-mr-create` updates the group variables via API. Cutover reads `RELEASE_CURRENT_BRANCH` from the group var.

Override without the group var: Run pipeline variable `RELEASE_BRANCH=upgrade/...`.

**GitLab CE:** `GET /version` → `"enterprise": false` means Approval rules are unavailable (Premium/Ultimate). On CE `approvals_before_merge` on projects is `null`; the approve job is not required for merge.

Initial setup (admin token from the environment, not a committed file):

```bash
GITLAB_ADMIN_TOKEN=CHANGE_ME \
  bash scripts/setup_gitlab_release_admin.sh --env PREPROD
GITLAB_ADMIN_TOKEN=CHANGE_ME \
  bash scripts/setup_gitlab_release_admin.sh --env PROD
```

### 2. Bot user `release-bot`

- Created by `setup_gitlab_release_admin.sh`
- Maintainer (or Owner, for group-variable API) on group `estate`
- Token → `RELEASE_BOT_TOKEN`

### 3. Approval rules (Premium/Ultimate only)

GitLab CE has no UI for Approval rules / re-authentication to approve.

On Premium, API:

| Action | Method | Path |
|--------|--------|------|
| List group rules | GET | `/api/v4/groups/:id/approval_rules` |
| Create rule | POST | `/api/v4/groups/:id/approval_rules` body `{"name":"Release bot","approvals_required":1,"user_ids":[BOT_ID]}` |
| Disable re-auth | PUT | `/api/v4/groups/:id/merge_request_approval_settings` body `{"require_reauthentication_to_approve":false}` |
| Project rule (fallback) | POST | `/api/v4/projects/:id/approval_rules` |

Self-managed group rules may need feature flag `approval_group_rules`.

UI (Premium): Group → Settings → Merge requests → Approval rules.

### 4. CI Job Token (clone common-ci from a helm repo)

UI path: project **`estate/common-ci`** → Settings → **CI/CD** → **Job token permissions** (not group Settings).

Allow group `estate` so helm repos can read common-ci via `CI_JOB_TOKEN`.

API (admin token; project id of common-ci is environment-specific):

```bash
# Check
curl -H "PRIVATE-TOKEN: CHANGE_ME" \
  "https://gitlab-preprod.example.com/api/v4/projects/CHANGE_ME/job_token_scope/groups_allowlist"

# Add group estate (id=CHANGE_ME)
curl -X POST -H "PRIVATE-TOKEN: CHANGE_ME" -H "Content-Type: application/json" \
  -d '{"target_group_id": CHANGE_ME}' \
  "https://gitlab-preprod.example.com/api/v4/projects/CHANGE_ME/job_token_scope/groups_allowlist"
```

Docs: https://docs.gitlab.com/api/project_job_token_scopes/

Creating an MR in the same repo via `CI_JOB_TOKEN` is usually enough on GitLab 16+ without extra scope.

### 5. Protected branches

- `main`: merge for Maintainers only; the CI merge job uses the bot token (Maintainer)
- Upgrade branches: leave unprotected (engineers push from laptops)

### 6. Push common-ci and root `.gitlab-ci.yml` into helm repos

After merge in GitLab:

1. Push `common-ci` (`releases/*`)
2. Push root `.gitlab-ci.yml` to every repo in `manifests/preprod-release-repos.txt`

## Run pipeline (`common-ci`)

**Cutover:** Run pipeline on branch `main` (web). Extra variables not required.

**Revert:** Run pipeline + variable:

```
REVERT_RELEASE_BRANCH = upgrade/shop-app-X-Y-prod
```

Then manual job `release-revert-all-mrs`.

## Troubleshooting

| Symptom | Cause | Action |
|---------|-------|--------|
| No release jobs in the pipeline | not web, or not branch `main` | Run pipeline on `main` |
| `release-preflight` failed (`allow_failure`) | `RELEASE_CURRENT_BRANCH` unset | push an upgrade branch or set `RELEASE_BRANCH` |
| approve `IDEMPOTENT OK` / merge ERROR already merged | cutover already done | check main; a new release needs a new upgrade branch |
| merge ERROR approve other pipeline | merge in a new pipeline without approve | approve + merge in the same Run pipeline |
| approve/merge `SKIP` (idempotent) | MR already approved/merged | expected on a rerun |
| `release-mr-create` skipped | not a new branch, or branch does not match `upgrade/shop-app-*-estate-*` | first push of a new upgrade branch |
| clone common-ci failed | job token scope | Token Access, see §4 |
| approve 401/403 | token or not an approver | bot Maintainer + approval rules |
| merge blocked | approvals / draft MR | wait for the approve job |
| revert on the active branch | REVERT == RELEASE_CURRENT | set a different branch |
| `release-04-wait-ansible-sync` timeout | ansible pipeline did not start / hung | check pipeline `estate/ansible` on `main`, re-run wait |
| `release-05` missing `ansible_ssh_key` | sync did not write keys / no CI var | check ansible sync job + `ANSIBLE_SSH_PRIVATE_KEY_B64` |
| `release-05` docker `-it` / TTY error | old `run_docker_app.sh` | update ansible main (CI-friendly docker flags) |
