# ansible-runner

Docker image used by `run_prepare.sh` / `run_edge.sh`: **ansible-core**, **jmespath** (`json_query`), and Galaxy collections. Playbooks mount at `/work`; SSH key at `/work/.ssh_key_mount`. `--network host` so the control node reaches VPS addresses the same way a laptop would.

Default tag in wrappers: `example/ansible-runner:1.1` (override with `ANSIBLE_IMAGE` / `--image`).

```bash
docker build -t example/ansible-runner:1.1 -f Dockerfile .
```

`--no-tty` on the run scripts is the CI / non-interactive path (no `-it`).

Used by: [`../../ansible-bootstrap/`](../../ansible-bootstrap/), [`../../ansible-edge/`](../../ansible-edge/).
