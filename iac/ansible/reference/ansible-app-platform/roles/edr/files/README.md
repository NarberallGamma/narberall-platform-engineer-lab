# EDR agent package

The edr-vendor `.deb` stays on the control node. The local package belongs at `edr-agent.deb` in this directory. The package is not stored in git.

Playbook variable `file` points at `edr-agent.deb`. Install uses that path under `tmpdir`.
