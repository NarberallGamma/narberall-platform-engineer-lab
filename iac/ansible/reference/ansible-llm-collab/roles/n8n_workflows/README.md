# Role n8n_workflows

Sync n8n workflows from the repository (GitOps): load JSON from `files/workflows/*.json` and create/update workflows in n8n via REST API.

## Nextcloud Groupfolders: two workflows (form + webhook)

- **Form** (`nextcloud_groupfolders_form.json`): `formPath` → URL of the form `{n8n_base}/form/nextcloud-groupfolders`. Fields: **Profile** (required: `nextcloud-dev` or `regul`), **Client name** (for single-client modes), checkboxes **reapply for all clients** (`--all-clients`) and **ACL only for one client without MKCOL** (`--permissions-only`). If both checkboxes are set, the mode is treated as "all clients" (the broader scenario); keep one mode, or leave both off for the standard MKCOL run for one client.
- **API** (`nextcloud_groupfolders_webhook.json`): the Webhook node has `path: nextcloud-groupfolders-api` → POST to `{n8n_base}/webhook/.../nextcloud-groupfolders-api` with a JSON body. Same fields as the form (`profile`, optional `host`/`limit` when `profile` is omitted — same as `--limit`), `client_name`, optionally `reapply_all_clients` and `permissions_only` (booleans). The command for the control node is built in the **Execute a command** node: `sudo -u ansible /ansible/scripts/run/run_nextcloud_groupfolders.sh …` — see script `ansible/scripts/run/run_nextcloud_groupfolders.sh`. The `path` value must **not** match `formPath`: otherwise activating the second workflow makes n8n return **Conflicting Webhook Path** (both triggers reserve the same segment under `/webhook/`).
- In **(Form)** the JSON has only **On form submission** and **Execute a command**; there are no Webhook / Respond to Webhook nodes there (those are in the **(Webhook)** workflow). If stale nodes remain in the UI — run playbook sync again; the graph in n8n must match the repository after PUT.

## Requirements

- Role **n8n_init** runs before this one (API key from Vault).
- In `group_vars/n8n_workflows.yml`: `n8n_base_url`, `n8n_workflows_to_sync`.
- In n8n after the first deploy, bind credentials manually if needed:
  - **SSH Ansible Host** — on the "Execute a command" node (connection to the Ansible control node).
  - **Webhook authentication** — the repository JSON sets `headerAuth`; JWT/other can be selected in the n8n UI and the credential bound to the Webhook node.

## Webhook: response (stdout/stderr)

- In the webhook workflow in the repository the **Respond to Webhook** node returns HTML with the result.
- The webhook and form response is built by **Respond to Webhook**: the browser gets HTML with the command output (stdout), errors (stderr), exit code, and a hint where to find the full log: on the Ansible control node under `/ansible/artifacts/logs` and in the n8n UI (Executions).
- Output is available **after the command finishes**: the Execute Command node in n8n does not stream stdout/stderr as it runs (real-time streaming is not available through n8n). For a live log during the run: on the control node run `tail -f /ansible/artifacts/logs/<log_file>.log` or open the run in n8n → Executions after start and watch output as it appears (if the UI refreshes).

## Form: authentication

Form Trigger supports Basic Authentication. In the JSON, authentication is off by default. To enable: in n8n on the "On form submission" node select Authentication → Basic Auth and bind the created credential. Alternatively add a hidden field to the form (e.g. a secret key) and check it in a separate node before Execute command.

## Adding new workflows

1. Place the JSON in `roles/n8n_workflows/files/workflows/<name>.json` (without `id`, `createdAt`, `updatedAt` at the root).
2. Add `<name>` to `n8n_workflows_to_sync` in `group_vars/n8n_workflows.yml`.
3. Run playbook `playbooks/n8n_workflows.yml`.

A workflow in n8n is looked up by the `name` field in the JSON; on a match: GET the full workflow, merge with the repo (`name`, `nodes`, `connections`, `settings`, and `meta` if present), then PUT. Otherwise — POST. Do not pass the body in `uri` as `| to_json` together with `body_format: json` (risk of 400).
