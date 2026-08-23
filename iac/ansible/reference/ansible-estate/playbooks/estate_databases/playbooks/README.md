# Estate PostgreSQL playbooks (RDS)

English: playbooks in this folder recreate RDS PostgreSQL databases, split Flyway/DDL vs app DML users (`schema_flyway` / `treasury_user`), and grant extra **read-only** and **read-write** accounts across user schemas. Destructive restore is labelled below. Hub: [`../../../`](../../../). Case: [`../../../../../../../case-studies/10-ansible-estate.md`](../../../../../../../case-studies/10-ansible-estate.md).

Playbooks in this folder work with estate RDS PostgreSQL: recreate databases, split users (`schema_flyway` / `treasury_user`), and create extra **read-only** and **read-write** accounts (DML and CREATE) in **all user schemas** of each database.

---

## 1. Database recreate playbook (`restore.yaml`)

### Description

The playbook drops the listed databases, creates them again with UTF8 encoding and locale en_US.UTF-8, and recreates schema `public` owned by `treasury_user`.

### Warning

**The playbook fully deletes the listed databases and all data in them.** Use only when the data may be discarded or will be restored from backup.

### What the playbook does

1. Terminates all active connections to the listed databases
2. Drops the databases (if they exist) — **all data is deleted**
3. Creates new databases with UTF8 encoding, locale en_US.UTF-8, database owner `treasury_user`
4. Drops schema `public` (cascade)
5. Creates a clean schema `public` owned by `treasury_user`

### Run

**Via script (recommended):**

```bash
./scripts/run/run_db_restore.sh treasury_onboarding
./scripts/run/run_db_restore.sh all
./scripts/run/run_db_restore.sh treasury_contract --check
```

**Directly via Ansible:**

```bash
ansible-playbook restore.yaml --extra-vars "db_name=treasury_onboarding"
ansible-playbook restore.yaml --extra-vars "db_list=['treasury_contract','treasury_audit']"
ansible-playbook restore.yaml
ansible-playbook restore.yaml --syntax-check
```

### After recreating databases

- When **user split** is in use (`schema_flyway` / `treasury_user`), run **schema_flyway_setup.yaml** — it grants the required privileges to treasury_user and schema_flyway.
- When schema_flyway is **not** in use, treasury_user privileges are set through the database-management playbooks (restore and extra tasks when needed).
- Restore data from backup when needed.

---

## 2. schema_flyway setup and privilege split (`schema_flyway_setup.yaml`)

### Purpose

- Create user **schema_flyway** and split privileges: **schema_flyway** — Flyway/DDL (schema and object owner), **treasury_user** — application (DML) and connectors (including replication).
- Uses the same database list and the same collections as `restore.yaml`.

### What the playbook does

1. Creates user `schema_flyway` with the given password.
2. Grants **treasury_user** **REPLICATION** (for Debezium / logical replication connectors).
3. In each database from the list:
   - grants `schema_flyway` CONNECT, USAGE and CREATE on schema `public`, and sets schema `public` owner to `schema_flyway`;
   - sets the owner of all tables and sequences in `public` to `schema_flyway`;
   - grants `treasury_user` USAGE on the schema, DML (SELECT, INSERT, UPDATE, DELETE) on tables, sequence privileges, and EXECUTE on functions;
   - sets default privileges for new objects created by `schema_flyway` so `treasury_user` receives the required privileges automatically.

After that the DDL/Flyway vs DML/application split should hold (do not override privileges by hand).

### Variables (in the playbook or --extra-vars)

- `pg_host`, `pg_port`, `pg_admin_user`, `pg_admin_password` — connect as admin (root).
- `treasury_user`, `treasury_password` — application user (password is not used in the tasks).
- `schema_flyway`, `schema_flyway_password` — Flyway user to create and its password.
- `db_list` or `db_name` — database list or a single database (same as `restore`).

### Run

**Via script (from the ansible directory root, recommended):**

```bash
./scripts/run/run_schema_flyway_setup.sh all
./scripts/run/run_schema_flyway_setup.sh treasury_contract
./scripts/run/run_schema_flyway_setup.sh treasury_contract --check
```

Set passwords in playbook `schema_flyway_setup.yaml` (vars) or pass: `--extra-vars "pg_admin_password=... schema_flyway_password=..."`.

**Directly via Ansible:**

```bash
cd playbooks/estate_databases/playbooks
ansible-playbook schema_flyway_setup.yaml -i "localhost,"
ansible-playbook schema_flyway_setup.yaml -i "localhost," --extra-vars "db_name=treasury_contract"
ansible-playbook schema_flyway_setup.yaml -i "localhost," --extra-vars "db_list=['treasury_contract','treasury_web'] pg_admin_password=... schema_flyway_password=..."
```

### After a successful run

- Store `schema_flyway` credentials in Vault.
- In each application values/config: Flyway uses `spring.flyway.user` / `spring.flyway.password` from Vault, the application uses `spring.datasource.*` (treasury_user), as in Runbook item 9.

---

## 3. Read-only user playbook (`ro_user_setup.yaml`)

### Purpose

Extra account (audit, InfoSec, analytics): **GRANTs only**, no OWNER change and no edits to `treasury_user` / `schema_flyway`.

- CONNECT on the database
- USAGE + SELECT on tables and sequences in **all user schemas** (discovered at runtime)
- `ALTER DEFAULT PRIVILEGES FOR ROLE <default_privileges_for_role>` for **new** objects created by Flyway (`schema_flyway` by default)

**Object OWNER is not transferred.** Variable `default_privileges_for_role` names **whose** future objects receive the auto-grant; it does not make the extra account an owner.

### Variables

- `pg_host`, `pg_port`, `pg_admin_user`, `pg_admin_password` — connect as admin.
- **`ro_user`**, **`ro_password`** — required.
- `default_privileges_for_role` — for `ALTER DEFAULT PRIVILEGES ... FOR ROLE` (default `schema_flyway`).
- `db_name` or `db_list` — same as the other playbooks in this folder.

### Run

**Via script (from the ansible directory root):**

```bash
./scripts/run/run_ro_user_setup.sh all --extra-vars "ro_user=superset_main ro_password=... pg_admin_password=..."
./scripts/run/run_ro_user_setup.sh treasury_contract --extra-vars "ro_user=superset_main ro_password=... pg_admin_password=..."
./scripts/run/run_ro_user_setup.sh all --extra-vars "ro_user=superset_main ro_password=... pg_admin_password=..." --check
```

**Directly via Ansible:**

```bash
cd playbooks/estate_databases/playbooks
ansible-playbook ro_user_setup.yaml -i "localhost," --extra-vars "ro_user=superset_main ro_password=... pg_admin_password=..."
ansible-playbook ro_user_setup.yaml -i "localhost," --extra-vars "ro_user=superset_main ro_password=... pg_admin_password=... db_name=treasury_contract"
```

### Limits

- System schemas `pg_*` and `information_schema` are not touched.
- SELECT only (no EXECUTE on functions). Extend the role by hand when needed.

---

## 4. Read-write user playbook (`rw_user_setup.yaml`)

### Purpose

Extra operations account: **edit data via GRANT**, no OWNER and no CREATE on schemas.

- CONNECT on the database
- USAGE on the schema (no CREATE)
- ALL PRIVILEGES on existing tables, sequences, functions (DML: SELECT/INSERT/UPDATE/DELETE and similar)
- `ALTER DEFAULT PRIVILEGES FOR ROLE schema_flyway` for future Flyway objects

**OWNER is not required** to edit data in existing tables. ALTER TABLE / DROP TABLE on objects owned by `schema_flyway` is **not granted** by this playbook (PostgreSQL limitation). Table-structure DDL stays with `schema_flyway` / `schema_flyway_setup`.

### Variables

- `pg_host`, `pg_port`, `pg_admin_user`, `pg_admin_password` — connect as admin.
- **`rw_user`**, **`rw_password`** — required when `manage_password=true` (default).
- **`manage_password`** — `false`: GRANTs only, password is not changed (account already created in the cloud).
- `default_privileges_for_role` — for `ALTER DEFAULT PRIVILEGES ... FOR ROLE` (default `schema_flyway`).
- `db_name` or `db_list` — same as the other playbooks in this folder.

### Run

**Via script (from the ansible directory root):**

```bash
./scripts/run/run_rw_user_setup.sh all --extra-vars "rw_user=migration_tool rw_password=... pg_admin_password=..."
./scripts/run/run_rw_user_setup.sh treasury_contract --extra-vars "rw_user=migration_tool rw_password=... pg_admin_password=..."
./scripts/run/run_rw_user_setup.sh all --extra-vars "rw_user=estate_analyst manage_password=false pg_admin_password=..."
./scripts/run/run_rw_user_setup.sh all --extra-vars "rw_user=migration_tool rw_password=... pg_admin_password=..." --check
```

**Directly via Ansible:**

```bash
cd playbooks/estate_databases/playbooks
ansible-playbook rw_user_setup.yaml -i "localhost," --extra-vars "rw_user=migration_tool rw_password=... pg_admin_password=..."
ansible-playbook rw_user_setup.yaml -i "localhost," --extra-vars "rw_user=migration_tool rw_password=... pg_admin_password=... db_name=treasury_contract"
ansible-playbook rw_user_setup.yaml -i "localhost," --extra-vars "rw_user=migration_tool rw_password=... pg_admin_password=... db_list=['treasury_contract','treasury_audit']"
```

### Limits

- System schemas `pg_*` and `information_schema` are not touched.
- No CREATE on the schema, no OWNER change. Table-structure DDL: `schema_flyway` only.

---

## 5. Extra-role teardown playbook (`drop_db_user.yaml`)

### Purpose

Revoke GRANTs and default privileges **only for the named extra account** (for example `estate_0006`) before deletion. For `treasury_user`, `schema_flyway`, `root`, and system roles this is **refused**.

**No REASSIGN OWNED.** Order:

1. Terminate role sessions (if any)
2. REVOKE default privileges (dynamically from `pg_default_acl`)
3. Explicit REVOKE on schemas/objects (no DROP OWNED: root on RDS is not superuser)
4. `REVOKE CONNECT ON DATABASE`
5. Optional `DROP ROLE` (`drop_role_after_cleanup=true`, default false)

### Run

```bash
./scripts/run/run_drop_db_user.sh all --extra-vars "drop_user=estate_0006 pg_admin_password=..."
./scripts/run/run_drop_db_user.sh all --extra-vars "drop_user=estate_0006 drop_role_after_cleanup=true pg_admin_password=..."
./scripts/run/run_drop_db_user.sh all --extra-vars "drop_user=estate_0006 pg_admin_password=..." --check
```

---

## Shared: default database list

Playbooks `ro_user_setup`, `rw_user_setup`, and `drop_db_user` use **`default_databases`** in vars (24 estate application databases, RDS snapshot 2026-07). **`openobserve` is not included** (separate observability database, no grants):

`cryptopro_service`, `hsm`, `keycloak`, `nodes_btc`, `nodes_eth`, `nodes_tron`, `treasury_aml`, `treasury_api`, `treasury_csp`, `treasury_aml`, `treasury_audit`, `treasury_auth_provider`, `treasury_contract`, `treasury_contract_restored_3`, `treasury_csp`, `treasury_notification`, `treasury_onboarding`, `treasury_otp`, `treasury_rates`, `treasury_report`, `treasury_safe_deal_adapter`, `treasury_lp_adapter`, `treasury_treasury_adapter`, `treasury_web`.

Playbooks `restore` and `schema_flyway_setup` require an explicit `db_name` / `db_list` by default (empty `default_databases` for safety).

Override: `--extra-vars "db_name=..."` or `--extra-vars "db_list=['db1','db2']"`.

---

## Connection parameters

Set in the playbooks (or via --extra-vars):

- `pg_host` — RDS PostgreSQL IP
- `pg_port` — 5432
- `pg_admin_user` — root (or another superuser)
- `pg_admin_password` — administrator password
- `treasury_user` / `treasury_password` — application user (for restore and when needed)
- `schema_flyway` / `schema_flyway_password` — schema_flyway_setup only

---

## Requirements

- Ansible collections: `community.postgresql`, `community.general` (see `requirements.yml`)
- On the control node: psycopg2 (installed by schema_flyway tasks when needed)
- For the wrapper scripts: Docker, Ansible EE when needed

---

## File layout

```
playbooks/estate_databases/playbooks/
├── restore.yaml              # Recreate databases
├── drop_db.yaml              # Drop databases (no recreate)
├── schema_flyway_setup.yaml     # schema_flyway and privilege setup
├── ro_user_setup.yaml        # Read-only: GRANT SELECT (no OWNER)
├── rw_user_setup.yaml        # Read-write: GRANT DML (no OWNER)
├── drop_db_user.yaml         # Revoke extra-role grants (no REASSIGN)
├── README.md                 # This file
├── ansible.cfg
├── requirements.yml
└── roles/
    ├── db/
    │   └── tasks/main.yml    # Recreate databases
    ├── schema_flyway/
    │   └── tasks/main.yml    # schema_flyway + treasury_user privileges (DML + REPLICATION)
    ├── ro_user/
    │   └── tasks/main.yml    # RO: GRANT SELECT, no OWNER
    ├── rw_user/
    │   └── tasks/main.yml    # RW: GRANT DML, no OWNER
    └── drop_db_user/
        └── tasks/main.yml    # Revoke grants + DROP ROLE, no REASSIGN
```

---

## Troubleshooting

**Database connection error** — typically `pg_host`, passwords, or RDS reachability from the network.

**Weak password** — set a stronger password by hand via psql when creating the user.

**Database will not drop** — close all connections; use a forced session-termination script when needed.

**Application lacks privileges after schema_flyway_setup** — confirm that treasury_user received REPLICATION and DML on all required schemas/tables.
