# Ubuntu host audit

Ansible copies `audit.sh` to the host, runs it with sudo, and writes one log per inventory name under `./logs/`. Aimed at Ubuntu 18.04-class boxes; the script still reads the usual systemd / apt / docker / kubectl surfaces.

```bash
cp inventory.ini.example inventory.ini
ansible-playbook -i inventory.ini run_audit.yml
```

Live `inventory.ini` stays local. Logs stay local.
