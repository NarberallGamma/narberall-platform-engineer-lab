# Плейбуки управления базами estate (PostgreSQL)

В этой папке плейбуки для работы с RDS PostgreSQL проекта estate: пересоздание баз данных, настройка разделения пользователей (schema_flyway / treasury_user), создание **read-only** учёток и **read-write** учёток (DML и CREATE) во **всех пользовательских схемах** каждой БД.

---

## 1. Плейбук пересоздания баз данных (`restore.yaml`)

### Описание

Плейбук удаляет указанные базы данных, создаёт их заново с кодировкой UTF8 и локалью en_US.UTF-8, пересоздаёт схему `public` с владельцем `treasury_user`.

### ⚠️ ВНИМАНИЕ

**Плейбук полностью удаляет указанные базы данных и все данные в них!** Используйте только когда данные можно потерять или они будут восстановлены из бэкапа.

### Что делает плейбук

1. Завершает все активные подключения к указанным базам данных
2. Удаляет базы данных (если существуют) — **все данные будут удалены**
3. Создаёт новые базы с кодировкой UTF8, локалью en_US.UTF-8, владелец БД — `treasury_user`
4. Удаляет схему `public` (каскадно)
5. Создаёт чистую схему `public` с владельцем `treasury_user`

### Запуск

**Через скрипт (рекомендуется):**

```bash
./scripts/run/run_db_restore.sh treasury_onboarding
./scripts/run/run_db_restore.sh all
./scripts/run/run_db_restore.sh treasury_contract --check
```

**Напрямую через Ansible:**

```bash
ansible-playbook restore.yaml --extra-vars "db_name=treasury_onboarding"
ansible-playbook restore.yaml --extra-vars "db_list=['treasury_contract','treasury_audit']"
ansible-playbook restore.yaml
ansible-playbook restore.yaml --syntax-check
```

### После пересоздания БД

- Если используете **разделение пользователей** (schema_flyway / treasury_user), запустите плейбук **schema_flyway_setup.yaml** — он выдаст treasury_user и schema_flyway нужные права.
- Если **не** используете schema_flyway, права treasury_user настраиваются через плейбуки управления базами (restore и при необходимости дополнительные задачи).
- При необходимости восстановите данные из бэкапа.

---

## 2. Плейбук настройки schema_flyway и разграничения прав (`schema_flyway_setup.yaml`)

### Назначение

- Создать пользователя **schema_flyway** и разграничить права: **schema_flyway** — Flyway/DDL (владелец схемы и объектов), **treasury_user** — приложение (DML) и коннекторы (в т.ч. репликация).
- Используется тот же список БД и те же коллекции, что и в `restore.yaml`.

### Что делает плейбук

1. Создаёт пользователя `schema_flyway` с заданным паролем.
2. Выдаёт **treasury_user** право **REPLICATION** (для Debezium / logical replication коннекторов).
3. В каждой БД из списка:
   - выдаёт `schema_flyway` CONNECT, USAGE и CREATE на схему `public`, переводит владельца схемы `public` на `schema_flyway`;
   - переводит владельца всех таблиц и последовательностей в `public` на `schema_flyway`;
   - выдаёт `treasury_user` USAGE на схему, DML (SELECT, INSERT, UPDATE, DELETE) на таблицы, права на последовательности и EXECUTE на функции;
   - настраивает default privileges для новых объектов, созданных `schema_flyway`, чтобы `treasury_user` автоматически получал нужные права.

После этого разделение DDL/Flyway и DML/приложение должно сохраняться (не переопределять права вручную).

### Переменные (в плейбуке или --extra-vars)

- `pg_host`, `pg_port`, `pg_admin_user`, `pg_admin_password` — подключение под админом (root).
- `treasury_user`, `treasury_password` — пользователь приложения (пароль в тасках не используется).
- `schema_flyway`, `schema_flyway_password` — создаваемый пользователь Flyway и его пароль.
- `db_list` или `db_name` — список БД или одна БД (как в `restore`).

### Запуск

**Через скрипт (из корня каталога ansible, рекомендуется):**

```bash
./scripts/run/run_schema_flyway_setup.sh all
./scripts/run/run_schema_flyway_setup.sh treasury_contract
./scripts/run/run_schema_flyway_setup.sh treasury_contract --check
```

Пароли задать в плейбуке `schema_flyway_setup.yaml` (vars) или передать: `--extra-vars "pg_admin_password=... schema_flyway_password=..."`.

**Напрямую через Ansible:**

```bash
cd playbooks/estate_databases/playbooks
ansible-playbook schema_flyway_setup.yaml -i "localhost,"
ansible-playbook schema_flyway_setup.yaml -i "localhost," --extra-vars "db_name=treasury_contract"
ansible-playbook schema_flyway_setup.yaml -i "localhost," --extra-vars "db_list=['treasury_contract','treasury_web'] pg_admin_password=... schema_flyway_password=..."
```

### После выполнения

- Учётные данные `schema_flyway` положить в Vault.
- В values/конфиге каждого приложения: для Flyway — `spring.flyway.user` / `spring.flyway.password` из Vault, для приложения — `spring.datasource.*` (treasury_user), как в п. 9 Runbook.

---

## 3. Плейбук read-only пользователя (`ro_user_setup.yaml`)

### Назначение

Дополнительная учётка (аудит, ИБ, аналитика): **только GRANT**, без смены OWNER и без правок `treasury_user` / `schema_flyway`.

- CONNECT на БД
- USAGE + SELECT на таблицы и последовательности во **всех пользовательских схемах** (обнаруживаются в runtime)
- `ALTER DEFAULT PRIVILEGES FOR ROLE <default_privileges_for_role>` для **новых** объектов, которые создаёт Flyway (`schema_flyway` по умолчанию)

**OWNER объектов не передаётся.** Переменная `default_privileges_for_role` указывает, **чьи** будущие объекты получат auto-grant, а не делает доп. учётку владельцем.

### Переменные

- `pg_host`, `pg_port`, `pg_admin_user`, `pg_admin_password` — подключение под админом.
- **`ro_user`**, **`ro_password`** — обязательны.
- `default_privileges_for_role` — для `ALTER DEFAULT PRIVILEGES ... FOR ROLE` (по умолчанию `schema_flyway`).
- `db_name` или `db_list` — как в других плейбуках этой папки.

### Запуск

**Через скрипт (из корня каталога ansible):**

```bash
./scripts/run/run_ro_user_setup.sh all --extra-vars "ro_user=superset_main ro_password=... pg_admin_password=..."
./scripts/run/run_ro_user_setup.sh treasury_contract --extra-vars "ro_user=superset_main ro_password=... pg_admin_password=..."
./scripts/run/run_ro_user_setup.sh all --extra-vars "ro_user=superset_main ro_password=... pg_admin_password=..." --check
```

**Напрямую через Ansible:**

```bash
cd playbooks/estate_databases/playbooks
ansible-playbook ro_user_setup.yaml -i "localhost," --extra-vars "ro_user=superset_main ro_password=... pg_admin_password=..."
ansible-playbook ro_user_setup.yaml -i "localhost," --extra-vars "ro_user=superset_main ro_password=... pg_admin_password=... db_name=treasury_contract"
```

### Ограничения

- Системные схемы `pg_*` и `information_schema` не затрагиваются.
- Только SELECT (без EXECUTE на функции). При необходимости расширить роль вручную.

---

## 4. Плейбук read-write пользователя (`rw_user_setup.yaml`)

### Назначение

Дополнительная учётка сопровождения: **редактирование данных через GRANT**, без OWNER и без CREATE на схемах.

- CONNECT на БД
- USAGE на схему (без CREATE)
- ALL PRIVILEGES на существующие таблицы, последовательности, функции (DML: SELECT/INSERT/UPDATE/DELETE и т.п.)
- `ALTER DEFAULT PRIVILEGES FOR ROLE schema_flyway` для будущих объектов Flyway

**OWNER не нужен** для правки данных в существующих таблицах. ALTER TABLE / DROP TABLE у объектов с owner `schema_flyway` через этот плейбук **не выдаётся** (ограничение PostgreSQL). DDL миграций остаётся у `schema_flyway` / `schema_flyway_setup`.

### Переменные

- `pg_host`, `pg_port`, `pg_admin_user`, `pg_admin_password` — подключение под админом.
- **`rw_user`**, **`rw_password`** — обязательны при `manage_password=true` (по умолчанию).
- **`manage_password`** — `false`: только GRANT, пароль не меняется (учётка уже создана в облаке).
- `default_privileges_for_role` — для `ALTER DEFAULT PRIVILEGES ... FOR ROLE` (по умолчанию `schema_flyway`).
- `db_name` или `db_list` — как в других плейбуках этой папки.

### Запуск

**Через скрипт (из корня каталога ansible):**

```bash
./scripts/run/run_rw_user_setup.sh all --extra-vars "rw_user=migration_tool rw_password=... pg_admin_password=..."
./scripts/run/run_rw_user_setup.sh treasury_contract --extra-vars "rw_user=migration_tool rw_password=... pg_admin_password=..."
./scripts/run/run_rw_user_setup.sh all --extra-vars "rw_user=estate_analyst manage_password=false pg_admin_password=..."
./scripts/run/run_rw_user_setup.sh all --extra-vars "rw_user=migration_tool rw_password=... pg_admin_password=..." --check
```

**Напрямую через Ansible:**

```bash
cd playbooks/estate_databases/playbooks
ansible-playbook rw_user_setup.yaml -i "localhost," --extra-vars "rw_user=migration_tool rw_password=... pg_admin_password=..."
ansible-playbook rw_user_setup.yaml -i "localhost," --extra-vars "rw_user=migration_tool rw_password=... pg_admin_password=... db_name=treasury_contract"
ansible-playbook rw_user_setup.yaml -i "localhost," --extra-vars "rw_user=migration_tool rw_password=... pg_admin_password=... db_list=['treasury_contract','treasury_audit']"
```

### Ограничения

- Системные схемы `pg_*` и `information_schema` не затрагиваются.
- Нет CREATE на схеме, нет смены OWNER. DDL структуры таблиц: только `schema_flyway`.

---

## 5. Плейбук снятия дополнительной роли (`drop_db_user.yaml`)

### Назначение

Снять GRANT-ы и default privileges **только у указанной доп. учётки** (например `estate_0006`) перед удалением. Для `treasury_user`, `schema_flyway`, `root` и системных ролей **запрещён**.

**Без REASSIGN OWNED.** Порядок:

1. Завершить сессии роли (если есть)
2. REVOKE default privileges (динамически по `pg_default_acl`)
3. Явный REVOKE на схемах/объектах (без DROP OWNED: root на RDS не superuser)
4. `REVOKE CONNECT ON DATABASE`
5. Опционально `DROP ROLE` (`drop_role_after_cleanup=true`, по умолчанию false)

### Запуск

```bash
./scripts/run/run_drop_db_user.sh all --extra-vars "drop_user=estate_0006 pg_admin_password=..."
./scripts/run/run_drop_db_user.sh all --extra-vars "drop_user=estate_0006 drop_role_after_cleanup=true pg_admin_password=..."
./scripts/run/run_drop_db_user.sh all --extra-vars "drop_user=estate_0006 pg_admin_password=..." --check
```

---

## Общее: список баз данных по умолчанию

Плейбуки `ro_user_setup`, `rw_user_setup` и `drop_db_user` используют **`default_databases`** в vars (24 прикладные БД estate, снимок RDS 2026-07). **`openobserve` не включена** (отдельная БД observability, grants не выдаются):

`cryptopro_service`, `hsm`, `keycloak`, `nodes_btc`, `nodes_eth`, `nodes_tron`, `treasury_aml`, `treasury_api`, `treasury_csp`, `treasury_aml`, `treasury_audit`, `treasury_auth_provider`, `treasury_contract`, `treasury_contract_restored_3`, `treasury_csp`, `treasury_notification`, `treasury_onboarding`, `treasury_otp`, `treasury_rates`, `treasury_report`, `treasury_safe_deal_adapter`, `treasury_lp_adapter`, `treasury_treasury_adapter`, `treasury_web`.

Плейбуки `restore` и `schema_flyway_setup` по умолчанию требуют явный `db_name` / `db_list` (пустой `default_databases` для безопасности).

Переопределение: `--extra-vars "db_name=..."` или `--extra-vars "db_list=['db1','db2']"`.

---

## Параметры подключения

Задаются в плейбуках (или через --extra-vars):

- `pg_host` — IP RDS PostgreSQL
- `pg_port` — 5432
- `pg_admin_user` — root (или другой суперпользователь)
- `pg_admin_password` — пароль администратора
- `treasury_user` / `treasury_password` — пользователь приложения (для restore и при необходимости)
- `schema_flyway` / `schema_flyway_password` — только для schema_flyway_setup

---

## Требования

- Коллекции Ansible: `community.postgresql`, `community.general` (см. `requirements.yml`)
- На контрол-ноде: psycopg2 (устанавливается тасками schema_flyway при необходимости)
- Для запуска через скрипт: Docker, Ansible EE при необходимости

---

## Структура файлов

```
playbooks/estate_databases/playbooks/
├── restore.yaml              # Пересоздание БД
├── drop_db.yaml              # Удаление БД (без recreate)
├── schema_flyway_setup.yaml     # Настройка schema_flyway и прав
├── ro_user_setup.yaml        # Read-only: GRANT SELECT (без OWNER)
├── rw_user_setup.yaml        # Read-write: GRANT DML (без OWNER)
├── drop_db_user.yaml         # Revoke grants доп. роли (без REASSIGN)
├── README.md                 # Этот файл
├── ansible.cfg
├── requirements.yml
└── roles/
    ├── db/
    │   └── tasks/main.yml    # Пересоздание БД
    ├── schema_flyway/
    │   └── tasks/main.yml    # schema_flyway + права treasury_user (DML + REPLICATION)
    ├── ro_user/
    │   └── tasks/main.yml    # RO: GRANT SELECT, без OWNER
    ├── rw_user/
    │   └── tasks/main.yml    # RW: GRANT DML, без OWNER
    └── drop_db_user/
        └── tasks/main.yml    # Revoke grants + DROP ROLE, без REASSIGN
```

---

## Устранение неполадок

**Ошибка подключения к БД** — проверьте `pg_host`, пароли, доступность RDS из сети.

**Weak password** — задайте более сложный пароль вручную через psql при создании пользователя.

**База не удаляется** — закройте все подключения; при необходимости используйте скрипт принудительного закрытия соединений.

**После schema_flyway_setup приложению не хватает прав** — при необходимости проверьте, что treasury_user получил REPLICATION и DML по всем нужным схемам/таблицам.
