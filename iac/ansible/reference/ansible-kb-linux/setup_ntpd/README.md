# Install and configure ntpd

Example inventory without generating from SSH config: `inventories/hosts.ini.example` (copy to `inventories/hosts.ini`). Generated `inventories/project_*.yml` files are not committed.

## All projects at once

Host list:

```bash
./update_inventory --project-filter ".*" && ansible-playbook setup_ntpd.yml --list-hosts
```

Install:

```bash
./update_inventory --project-filter ".*" && ansible-playbook setup_ntpd.yml
```

## One project

For a fictional project **aproject**.

Host list:

```bash
./update_inventory --project-filter "aproject" && ansible-playbook setup_ntpd.yml --limit localhost,project_aproject --list-hosts
```

Install:

```bash
./update_inventory --project-filter "aproject" && ansible-playbook setup_ntpd.yml --limit localhost,project_aproject
```
