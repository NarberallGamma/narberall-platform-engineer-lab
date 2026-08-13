# Reference implementations

Sanitized **proof of code** for automation described in [`../practice/`](../practice/). Terraform lives in [`../iac/terraform/`](../iac/terraform/). Ansible map: [`../iac/ansible/`](../iac/ansible/). Cloud experience: [`../iac/cloud/`](../iac/cloud/).

| Path | What is in git | Practice page |
|------|----------------|---------------|
| [`ansible-bootstrap/`](ansible-bootstrap/) | `prepare_servers`: apt, admin user `platform`, Docker CE from download.docker.com, sshd harden | [Edge platform](../practice/home-lab/edge-platform.md) |
| [`ansible-edge/`](ansible-edge/) | Full `xui_docker` role: Compose, ACME, panel API, Xray inbound/routing, socat, `USR1` | [Edge platform](../practice/home-lab/edge-platform.md) |
| [`monitoring-starter/`](monitoring-starter/) | `host_metrics`: sysstat, vnstat, disk CSV, report script | [Edge platform](../practice/home-lab/edge-platform.md) |
| [`utilities/ansible-runner/`](utilities/ansible-runner/) | Alpine runner image + build script | [Edge platform](../practice/home-lab/edge-platform.md), [MCP toolchain](../practice/workstation/mcp-ops-toolchain.md) |
| [`utilities/snap-pair/`](utilities/snap-pair/) | Paired snapper + ESP rsync | [OS workstation](../practice/home-lab/os-workstation.md) |
| [`utilities/mcp-replicate/`](utilities/mcp-replicate/) | MCP wrapper (token file, not git) | [AI lab](../practice/home-lab/ai-lab.md) |
| [`ai/`](ai/) | LLM compose, SD GPU compose, Kohya LoRA preset | [AI lab](../practice/home-lab/ai-lab.md) |
| [`apps/ssh-tunnel-android/`](apps/ssh-tunnel-android/) | Foreground Service, 6 sessions, balancer | [Android SSH](../practice/home-lab/android-ssh.md) |
| [`apps/ssh-tunnel-docker/`](apps/ssh-tunnel-docker/) | nginx stream + rolling SSH | [Android SSH](../practice/home-lab/android-ssh.md) |
| [`apps/ss-display/`](apps/ss-display/) | Example OLED config + user unit | [Pet projects](../practice/home-lab/pet-projects.md) |
| [`infra/`](infra/) | Redirect → `../iac/terraform/` | — |

Inventories use `*.example.com`. Credentials and `hosts.ini` are gitignored. Panel stream/dest knobs and ACME issue are **not** published.
