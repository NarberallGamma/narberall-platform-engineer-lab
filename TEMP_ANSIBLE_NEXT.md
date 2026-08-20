# TEMP: Ansible next (delete after the pass)

Handoff for the next chat. **Delete this file** when the Ansible inventory / sanitize pass is done. Not a hunter page.

Public language stays English. Chat with the owner may be Russian.

## Already published (do not rewrite)

Terraform slices are done (AWS multi-account, Huawei-class, VK / NOVA-class, VCD, Selectel VPC + dedicated Proxmox). Business leitmotif and architecture hub are in. Domain / SRE tables are expanded. **Do not** lead with cloud move. **Do not** break existing sanitized MD or `.tf`.

Ansible already on GitHub (keep as-is, add later):

- [`iac/ansible/README.md`](iac/ansible/README.md)
- [`iac/ansible/reference/ansible-bootstrap/`](iac/ansible/reference/ansible-bootstrap/)
- [`iac/ansible/reference/ansible-edge/`](iac/ansible/reference/ansible-edge/)
- [`iac/ansible/reference/ansible-payments-idplat/`](iac/ansible/reference/ansible-payments-idplat/)
- [`iac/ansible/reference/monitoring-starter/`](iac/ansible/reference/monitoring-starter/)
- [`iac/ansible/reference/ansible-runner/`](iac/ansible/reference/ansible-runner/)
- [case 08](case-studies/08-payments-swarm-autodeploy.md)

Repo-root `reference/` is gone. Kits live under each catalog (`iac/ansible/reference/`, `practice/home-lab/reference/`, `practice/workstation/reference/`).

Workstation MCP/scripts pass is in: [`practice/workstation/reference/`](practice/workstation/reference/) (`mcp-replicate/`, `mcp-agent/`, `scripts/`). Next is still Ansible thicken.

## Next: thicken Ansible (same habit as Terraform)

1. `git pull` `origin/main` on this lab first.
2. Inventory **all** Ansible trees under the private devops workspace (several projects). A longer private map travels with the workstation backup (career folder under `agent-analyzes`, not in this public repo).
3. Copy candidates to an **isolated staging** directory. Sanitize the **copies** only.
4. **Never** sanitize in-place under client / employer trees.
5. **Do not** merge a dump into this lab until a later curated slice is agreed (same rule as Terraform: one story, not the full private tree).
6. `SANITIZE.md` still applies: fake UUIDs, docs CIDRs, no real IPs, keys, tokens, employer names.
7. More slices will be added later. Additive only.

## Git for this lab

- Remote: `git@github.com:NarberallGamma/narberall-platform-engineer-lab.git`
- Author: Narberall `<narberall@users.noreply.github.com>`
- SSH (WSL): `~/.ssh/id_ed25519_narberall_work`, `IdentitiesOnly=yes`
- No assistant / tool names in commits or public files

## Home PC

Lab code is on GitHub (this file included). Private trees and career notes come from the workstation `7z` under `Desktop/Base/backups` (`workstation_full_YYYYMMDD.7z`). Restore: `Desktop/Base/backups/RESTORE_workstation_backup.md`.
