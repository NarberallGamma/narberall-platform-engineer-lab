# ansible-bootstrap

Host baseline role used before the edge panel: timezone, apt, admin user `platform`, SSH keys, optional Docker CE from **download.docker.com** (not distro `docker.io`), optional sshd harden.

Passwords are generated into `artifacts/credentials/` on the control node (gitignored). Inventory IPs stay in a local `hosts.ini`.

Practice write-up: [`../../../../practice/home-lab/edge-platform.md`](../../../../practice/home-lab/edge-platform.md). Runner image: [`../ansible-runner/`](../ansible-runner/). Next role: [`../ansible-edge/`](../ansible-edge/).

```bash
cp inventories/hosts.ini.example inventories/hosts.ini
./scripts/run_prepare.sh --limit vps-1.example.com -k /path/to/deploy_key
```

SSH harden is a **separate** run after the key is confirmed:

```bash
./scripts/run_prepare.sh --tags ssh_hardening -e enable_ssh_hardening=true
```

VCD / Terraform post-apply (packages, harden, EDR, host metrics) is the same habit with a thinner playbook: [`vcd-post-apply.yml.example`](vcd-post-apply.yml.example). Called from the CI catalog: [`../../../ci/`](../../../ci/).

## Keywords

Ansible, apt, Docker CE, sshd, sudo, artifacts, VCD, post-apply
