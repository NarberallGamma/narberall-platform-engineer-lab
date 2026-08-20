## Ansible playbooks to manage infrastructure

[[_TOC_]]

##### Requirements
1. Main requirements
    - python > 3.6
    - pip3

2. Create and activate virtualenv
```sh
python3 -m venv venv
source venv/bin/activate
```

3. Install requirements with pip3
```sh
pip3 install -r requirements.txt
```

4. Install mitogen
```sh
git submodule init
git submodule update
```

##### Debug
For debugging playbooks it's better to disable mitogen plugin.
Just comment this lines in ansible.cfg:
```sh
strategy_plugins = plugins/mitogen/ansible_mitogen/plugins/strategy
strategy = mitogen_linear
```

##### Tips
To deactivate virtualenv just run:
```sh
deactivate
```

##### Inventory and keys
Live inventory is `inventory/hosts.ini`, copied from `inventory/hosts.ini.example`. Postgres replication keys live under `projects/postgresql/roles/postgresql/files/.ssh/` and stay off git.

