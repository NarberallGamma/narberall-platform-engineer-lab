# PostgreSQL database migration scripts

Scripts to migrate PostgreSQL databases from a local server to a target server in VK Cloud.

## Migration layout

Migration runs in two stages:

1. **Create databases** (`create_databases_on_target_server.sh`) — prepare empty databases on the target server
2. **Migrate data** (`migrate_databases_to_target_server.sh`) — copy data from local databases into the target ones

## Extra scripts

3. **Change database owner** (`change_databases_owner.sh`) — change the owner of databases on the target server (after migration)

## Scripts

### 1. create_databases_on_target_server.sh

**Purpose:** Create empty databases on the target server before data migration.

**How it works:**
1. Reads the database list from the local PostgreSQL server
2. Excludes system and test databases (postgres, templates, names containing "Test")
3. Checks which databases already exist on the target server
4. Asks for confirmation before creating the missing databases
5. Creates databases with the configured owner on the target server

**Configurable variables:**

```bash
TARGET_HOST="10.10.2.251"              # target host or IP
TARGET_USER="svc_postgres_1c"         # PostgreSQL user on the target server
TARGET_PASSWORD="some_pass"           # user password (⚠️ REMOVE AFTER THE RUN!)
DB_OWNER="svc_postgres_1c"            # owner for all created databases
```

**Usage:**

```bash
# Create all available databases (default)
./create_databases_on_target_server.sh

# Create only databases listed in a file
./create_databases_on_target_server.sh dblist.txt
```

**Working with a database list:**
- When a list file is passed, the script **processes ONLY databases from that list**
- Example: 50 databases on the source, 3 names in the list — only those 3 are processed
- Each listed name is checked against the source instance
- A report of found and missing names is printed
- Only databases that exist on the source are created
- File format: one database per line; empty lines and lines starting with `#` are ignored

**⚠️ IMPORTANT — exact database names:**
- Names in the file must **match the source names exactly**
- **Case** is significant (`Database1` ≠ `database1`)
- **All characters** count (spaces, special characters, and so on)
- Copy the exact name from the source instance

Example `dblist.txt`:
```
database1
database2
# database3  # this line is ignored as a comment
database4
```

---

### 2. migrate_databases_to_target_server.sh

**Purpose:** Migrate data from local PostgreSQL databases to the target server.

**How it works:**
1. Reads the database list from the local server (with sizes)
2. Checks migration status for each database:
   - **Missing on the target → create first** (the script errors and stops)
   - Same table count → already migrated
   - Different table count → incomplete migration (needs a manual fix)
   - Empty databases → eligible for migration

**⚠️ Note:** The script restores into a database **with the same name** (`pg_restore -d "$dbname"`). Empty databases with the correct names must exist first (`create_databases_on_target_server.sh`).
3. Migrates databases in parallel (capped concurrent processes):
   - **Stage 1:** Local dump (pg_dump directory format with compression)
   - **Stage 2:** Restore on the target (pg_restore)
4. Checks success by table count
5. Writes reports and logs

**Notes:**
- Several databases migrate at once (up to 12 parallel processes)
- Adaptive pg_dump/restore jobs based on database size
- Free-disk check before migration starts
- Detailed logs in `migration_logs/`
- Temporary dumps are removed after a successful migration

**Configurable variables:**

```bash
MAX_PARALLEL=12                       # max concurrent migrations
                                      # FOR A TEST: 2
                                      # FOR PRODUCTION: 12

TARGET_HOST="10.10.2.251"              # target host or IP
TARGET_USER="svc_postgres_1c"         # PostgreSQL user on the target server
TARGET_PASSWORD="some_pass"           # user password (⚠️ REMOVE AFTER THE RUN!)
DUMP_DIR="/tmp/pg_dumps"              # temporary dump directory
```

**Usage:**

```bash
# Migrate all available databases (default)
./migrate_databases_to_target_server.sh

# Migrate only databases listed in a file
./migrate_databases_to_target_server.sh dblist.txt
```

**Working with a database list:**
- When a list file is passed, the script **migrates ONLY databases from that list**
- Example: 50 databases on the source, 3 names in the list — only those 3 are migrated
- Each listed name is checked against the source instance
- A report of found and missing names is printed
- Only databases that exist on the source **and already exist on the target** are migrated
- File format: one database per line; empty lines and lines starting with `#` are ignored

**⚠️ IMPORTANT — exact database names:**
- Names in the file must **match the source names exactly**
- **Case** is significant (`Database1` ≠ `database1`)
- **All characters** count (spaces, special characters, and so on)
- Copy the exact name from the source instance

**Logs and reports:**
- `migration_logs/[dbname].log` — detailed log per database
- `migration_logs/SUCCESS.log` — successfully migrated databases
- `migration_logs/WARNING.log` — warnings (table-count mismatch)
- `migration_logs/FAILED.log` — failed migrations

---

### 3. change_databases_owner.sh

**Purpose:** Change the owner of databases on the target server. Used after migration to set the correct owner.

**How it works:**
1. Connects to local PostgreSQL via peer authentication (as the postgres user)
2. Checks that the new owner role exists
3. If the role is missing — offers to create it with a password
4. Reads all databases (or names from a list file)
5. Shows the current owner of each database
6. Asks for confirmation before changing the owner
7. Changes the owner on the listed databases

**Configurable variables:**

```bash
NEW_OWNER="svc_postgres_1c"        # new database owner
NEW_OWNER_PASSWORD=""               # password for a new role (empty = prompt interactively)
AUTO_CREATE_USER=false              # true — create the role automatically, false — ask
```

**Usage:**

```bash
# Change owner on all available databases
./change_databases_owner.sh

# Change owner only on databases listed in a file
./change_databases_owner.sh dblist.txt
```

**Notes:**
- Runs on the target server (local connection via peer auth)
- Skips databases that already have the correct owner
- Shows a preview of changes before confirmation
- Supports a list file like the other scripts
- If the role is missing — can create it automatically or ask for confirmation

**Sample output:**
```
=== Databases to change owner ===
New owner: svc_postgres_1c

⊙ database1 (current owner: svc_postgres_1c - already correct)
→ database2 (current: postgres → new: svc_postgres_1c)
→ database3 (current: old_user → new: svc_postgres_1c)

=== Summary ===
Total databases: 3
Already have correct owner: 1
Need to change owner: 2
```

---

### 4. block_databases.sh

**Purpose:** Block databases for read/write or write-only. Used to protect databases during migration or maintenance.

**How it works:**
1. Connects to local PostgreSQL via peer authentication (as the postgres user)
2. Reads all databases (or names from a list file)
3. Shows the current status of each database (blocked / not blocked)
4. Asks for confirmation before blocking
5. Blocks the listed databases in the chosen mode

**Block modes:**

- `read_only` — write lock:
  - Sets `default_transaction_read_only = true`
  - Clients can read but cannot write
  - Used as a safe lock during migration

- `full` — full lock:
  - Sets `allow_connections = false`
  - Blocks all connections to the database
  - Used for full isolation

**Usage:**

```bash
# Write-lock all databases
./block_databases.sh read_only

# Write-lock specific databases
./block_databases.sh read_only dblist.txt

# Fully lock all databases
./block_databases.sh full

# Fully lock specific databases
./block_databases.sh full dblist.txt
```

**Notes:**
- Runs on the local server (peer auth)
- Supports a list file
- Shows a preview of changes before confirmation
- Skips databases that are already blocked

---

### 5. unblock_databases.sh

**Purpose:** Unblock databases (inverse of block_databases.sh).

**Usage:**

```bash
# Unblock all databases (clear read-only)
./unblock_databases.sh read_only

# Unblock specific databases
./unblock_databases.sh read_only dblist.txt

# Unblock all fully locked databases
./unblock_databases.sh full
```

**Notes:**
- Same flow as block_databases.sh
- Unblocks only databases locked in the matching mode

## Run order

### Standard migration (all databases)

1. **Set variables** in both scripts (host, user, password)
2. **Run the first script** to create databases on the target:
   ```bash
   ./create_databases_on_target_server.sh
   ```
3. **Run the second script** to migrate data:
   ```bash
   ./migrate_databases_to_target_server.sh
   ```
4. **Review logs** in `migration_logs/`
5. **(Optional) Change database owners** on the target:
   ```bash
   ./change_databases_owner.sh
   ```
   Or with a list file:
   ```bash
   ./change_databases_owner.sh dblist.txt
   ```
6. **Remove passwords** from the scripts after migration finishes

### Migration of specific databases from a list

1. **Get exact names from the source instance:**
   ```sql
   -- All databases except system ones
   SELECT datname FROM pg_database 
   WHERE datistemplate = false AND datname != 'postgres' 
   ORDER BY datname;
   ```

2. **Create a list file** (for example `dblist.txt`):
   ```
   database1
   database2
   database3
   ```
   **Note:** Copy names exactly as the query prints them.
2. **Set variables** in both scripts
3. **Create databases on the target:**
   ```bash
   ./create_databases_on_target_server.sh dblist.txt
   ```
   The script checks that each listed name exists on the source and prints a report
4. **Migrate data:**
   ```bash
   ./migrate_databases_to_target_server.sh dblist.txt
   ```
5. **Review logs** in `migration_logs/`
6. **(Optional) Change database owners** on the target:
   ```bash
   ./change_databases_owner.sh dblist.txt
   ```

## Requirements

### For migration scripts (create_databases, migrate_databases):
- Access to the local PostgreSQL server
- Network access to the target PostgreSQL server
- PostgreSQL tools: `psql`, `pg_dump`, `pg_restore`
- Enough free disk space (recommended > 50GB)
- Rights to create databases on the target server

### For management scripts (change_databases_owner, block/unblock_databases, check_databases_size):
- Scripts run **on the local server**
- Access to local PostgreSQL via peer authentication
- Run as `postgres` (or another superuser)
- PostgreSQL tools: `psql`

## Database filtering

### Without a list file (default)

Both scripts automatically exclude:
- System databases (`postgres`, templates)
- Names containing "Test"
- Names starting with "?"

### With a list file

- Only databases from the file are processed
- Each name is checked against the source instance
- A report of found and missing names is printed
- Only valid databases that exist on the source are processed

## Security

⚠️ **IMPORTANT:** After migration finishes, remove passwords from the `TARGET_PASSWORD` variables in both scripts.
