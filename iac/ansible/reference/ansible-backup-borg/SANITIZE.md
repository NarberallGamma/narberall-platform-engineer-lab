# Sanitize notes (this tree)

What was removed or rewritten before publish:

- Client inventory hostnames (replaced with `*.estate.example.com`)
- Live `authorized_keys` (replaced by `authorized_keys.example` with a lab public key)
- Vaulted `mysql-passwords.yml` (replaced by `mysql-passwords.yml.example` with `CHANGE_ME`)
- Live `vars` Borg server IP and project name (`vars.example` uses `10.10.20.10` and `estate`)
- Helm `secret-values.yaml`, Werf secret key, GitLab CI, Werf image, vendor alerting installer
- Alerting CLI name in scripts (generic `backup_notify`); password file paths under `/etc/backup/`

What stayed (on purpose):

- Full `borg_backup_*.sh` option parsers, prune defaults, and stream-into-Borg flow
- `borg_run_on.sh` copy / install / execute sequence (including proxy jump form)
- Russian operator comments inside the scripts (original job language)
- `borg-user.yaml` and `sudoers-borg` task graph

Do not add live SSH keys, vault ciphertext, or real Borg server addresses back into git.
