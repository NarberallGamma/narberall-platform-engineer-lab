#!/bin/bash
# migrate_databases_to_target_server.sh
# Usage: ./migrate_databases_to_target_server.sh [dblist_file.txt]
#   Если указан файл со списком БД - будет мигрировать только указанные БД из списка

# ============================================
# НАСТРОЙКИ (измените под ваши нужды)
# ============================================
MAX_PARALLEL=6  # ДЛЯ МИГРАЦИИ С БОЛЬШИМИ БД: 6 (меньше нагрузка на WAL), ДЛЯ ПРОДАКШЕНА: 12
TARGET_HOST="10.10.2.251"
TARGET_USER="svc_postgres_1c"
TARGET_PASSWORD=""  # ⚠️ УДАЛИТЬ ПОСЛЕ ЗАВЕРШЕНИЯ!
DUMP_DIR="/tmp/pg_dumps"

export PGPASSWORD="$TARGET_PASSWORD"

DB_LIST_FILE="$1"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
s
mkdir -p migration_logs
mkdir -p "$DUMP_DIR"

# ============================================
# ПРОВЕРКА ПОДКЛЮЧЕНИЙ И ВЫВОД ИНФОРМАЦИИ
# ============================================

echo "=== Connection Check ==="

# Проверка подключения к исходной СУБД (локальной)
echo "Checking connection to SOURCE server (localhost)..."
if psql -d postgres -c "SELECT version();" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Connected to source server${NC}"
    source_version=$(psql -d postgres -tAc "SELECT version();" 2>/dev/null | head -n1)
    echo "  PostgreSQL version: $source_version"
    source_db_count=$(psql -d postgres -tAc \
        "SELECT count(*) FROM pg_database WHERE datistemplate = false AND datname != 'postgres'" 2>/dev/null)
    echo "  Available databases: $source_db_count"
    echo "  Databases list:"
    psql -d postgres -tAc \
        "SELECT datname FROM pg_database WHERE datistemplate = false AND datname != 'postgres' ORDER BY datname" 2>/dev/null | \
        sed 's/^/    - /' | head -20
    if [ "$source_db_count" -gt 20 ]; then
        echo "    ... and $((source_db_count - 20)) more"
    fi
else
    echo -e "${RED}✗ Cannot connect to source server (localhost)!${NC}"
    echo "  Make sure PostgreSQL is running and accessible"
    exit 1
fi

echo ""

# Проверка подключения к целевой СУБД
echo "Checking connection to TARGET server ($TARGET_HOST)..."
if psql -h $TARGET_HOST -U $TARGET_USER -d postgres -c "SELECT version();" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Connected to target server${NC}"
    target_version=$(psql -h $TARGET_HOST -U $TARGET_USER -d postgres -tAc "SELECT version();" 2>/dev/null | head -n1)
    echo "  PostgreSQL version: $target_version"
    target_db_count=$(psql -h $TARGET_HOST -U $TARGET_USER -d postgres -tAc \
        "SELECT count(*) FROM pg_database WHERE datistemplate = false AND datname != 'postgres'" 2>/dev/null)
    echo "  Existing databases: $target_db_count"
    if [ "$target_db_count" -gt 0 ]; then
        echo "  Databases list:"
        psql -h $TARGET_HOST -U $TARGET_USER -d postgres -tAc \
            "SELECT datname FROM pg_database WHERE datistemplate = false AND datname != 'postgres' ORDER BY datname" 2>/dev/null | \
            sed 's/^/    - /' | head -20
        if [ "$target_db_count" -gt 20 ]; then
            echo "    ... and $((target_db_count - 20)) more"
        fi
    fi
else
    echo -e "${RED}✗ Cannot connect to target server ($TARGET_HOST)!${NC}"
    echo "  Check TARGET_HOST, TARGET_USER, TARGET_PASSWORD settings"
    echo "  Make sure target server is accessible and credentials are correct"
    exit 1
fi

echo ""
echo "========================================"
echo ""

# Проверка места
available_space=$(df -BG "$DUMP_DIR" | tail -1 | awk '{print $4}' | sed 's/G//')
echo "Available space for dumps: ${available_space}GB"
if [ "$available_space" -lt 50 ]; then
    echo -e "${RED}Warning: Less than 50GB free space.${NC}"
    read -p "Continue anyway? (yes/no): " confirm
    [ "$confirm" != "yes" ] && exit 1
fi
echo ""

# ============================================
# ФУНКЦИИ
# ============================================

check_db_exists() {
    local dbname=$1
    local exists=$(psql -h $TARGET_HOST -U $TARGET_USER -d postgres -tAc \
        "SELECT 1 FROM pg_database WHERE datname='$dbname'" 2>/dev/null)
    [ "$exists" = "1" ] && return 0 || return 1
}

get_table_count_local() {
    local dbname=$1
    psql -d "$dbname" -tAc \
        "SELECT count(*) FROM information_schema.tables WHERE table_schema='public'" 2>/dev/null || echo "0"
}

get_table_count_remote() {
    local dbname=$1
    psql -h $TARGET_HOST -U $TARGET_USER -d "$dbname" -tAc \
        "SELECT count(*) FROM information_schema.tables WHERE table_schema='public'" 2>/dev/null || echo "0"
}

get_db_size_local() {
    local dbname=$1
    psql -t -c "SELECT pg_database_size('$dbname')" 2>/dev/null | xargs
}

get_db_size_remote() {
    local dbname=$1
    psql -h $TARGET_HOST -U $TARGET_USER -d postgres -t -c \
        "SELECT pg_database_size('$dbname')" 2>/dev/null | xargs
}

# ============================================
# ПОЛУЧЕНИЕ СПИСКА БАЗ
# ============================================

echo "=== PostgreSQL Database Migration Tool ==="
echo "Source: localhost (current server)"
echo "Target: $TARGET_HOST"
echo "Max parallel: $MAX_PARALLEL"
echo "Dump directory: $DUMP_DIR"
if [ -n "$DB_LIST_FILE" ]; then
    echo "Using database list from file: $DB_LIST_FILE"
fi
echo ""

# Если передан файл со списком БД
if [ -n "$DB_LIST_FILE" ]; then
    if [ ! -f "$DB_LIST_FILE" ]; then
        echo -e "${RED}Error: File '$DB_LIST_FILE' not found!${NC}"
        exit 1
    fi
    
    echo "Reading database list from file: $DB_LIST_FILE"
    echo "Validating databases exist in source server..."
    
    # Получить все доступные БД из исходной СУБД с размерами
    psql -t -A -F'|' -c \
      "SELECT datname, pg_database_size(datname)
       FROM pg_database
       WHERE datistemplate = false
       AND datname != 'postgres'
       ORDER BY pg_database_size(datname) ASC" > databases_with_sizes.txt
    
    # Создать временный файл для проверки
    psql -t -A -c \
      "SELECT datname
       FROM pg_database
       WHERE datistemplate = false
       AND datname != 'postgres'" > /tmp/all_available_dbs.txt
    
    > databases_filtered.txt
    found_count=0
    not_found_count=0
    > /tmp/missing_dbs.txt
    
    # Проверить каждую БД из списка
    while IFS= read -r requested_db || [ -n "$requested_db" ]; do
        # Пропускаем пустые строки и комментарии, очищаем от пробелов и невидимых символов
        requested_db=$(echo "$requested_db" | sed 's/#.*$//' | tr -d '\r\n' | xargs)
        if [ -z "$requested_db" ]; then continue; fi
        
        # Экранируем одинарные кавычки в имени БД для SQL (удваиваем их)
        escaped_db=$(printf '%s' "$requested_db" | sed "s/'/''/g")
        
        # Проверить существование БД через SQL запрос
        db_exists=$(psql -t -A -c \
            "SELECT 1 FROM pg_database WHERE datname = '$escaped_db'" 2>/dev/null | tr -d '[:space:]')
        
        if [ "$db_exists" = "1" ]; then
            # БД существует, найти её размер из databases_with_sizes.txt
            db_info=$(grep "^${requested_db}|" databases_with_sizes.txt)
            if [ -n "$db_info" ]; then
                echo "$db_info" >> databases_filtered.txt
                ((found_count++))
            fi
        else
            echo -e "${RED}✗ Database not found in source: $requested_db${NC}"
            echo "$requested_db" >> /tmp/missing_dbs.txt
            ((not_found_count++))
        fi
    done < "$DB_LIST_FILE"
    
    echo ""
    echo "=== Validation Results ==="
    echo -e "${GREEN}Found in source: $found_count${NC}"
    if [ $not_found_count -gt 0 ]; then
        echo -e "${RED}Not found in source: $not_found_count${NC}"
        echo "Missing databases:"
        while IFS= read -r missing_db; do
            echo -e "  ${RED}  - $missing_db${NC}"
        done < /tmp/missing_dbs.txt
        echo ""
        read -p "Continue with found databases only? (yes/no): " confirm_continue
        if [ "$confirm_continue" != "yes" ]; then
            echo "Cancelled."
            exit 0
        fi
    fi
    
    if [ $found_count -eq 0 ]; then
        echo -e "${RED}No valid databases found in source server!${NC}"
        exit 1
    fi
    
    rm -f /tmp/all_available_dbs.txt /tmp/missing_dbs.txt
else
    # Получить список баз с правильным форматированием (старая логика)
    echo "Fetching database list from local server..."
    psql -t -A -F'|' -c \
      "SELECT datname, pg_database_size(datname)
       FROM pg_database
       WHERE datistemplate = false
       AND datname != 'postgres'
       AND datname NOT LIKE '%Test%'
       AND datname NOT LIKE '?%'
       ORDER BY pg_database_size(datname) ASC" > databases_with_sizes.txt
    
    # Фильтрация (старая логика)
    > databases_filtered.txt
    while IFS='|' read -r dbname size_bytes; do
        if [ -z "$dbname" ]; then continue; fi
        if [[ "$dbname" =~ ^\? ]] || [[ "$dbname" =~ Test ]]; then
            echo -e "${RED}✗ Excluding: $dbname${NC}"
            continue
        fi
        echo "$dbname|$size_bytes" >> databases_filtered.txt
    done < databases_with_sizes.txt
fi

# ============================================
# ПРОВЕРКА СТАТУСА МИГРАЦИИ
# ============================================

echo ""
echo "Checking migration status (comparing table counts)..."
> databases_to_migrate.txt
> databases_already_migrated.txt
> databases_not_exist.txt
> databases_incomplete.txt

while IFS='|' read -r dbname size_bytes; do
    if [ -z "$dbname" ]; then continue; fi
    
    # Убираем пробелы из size_bytes и проверяем что это число
    size_bytes=$(echo "$size_bytes" | tr -d ' ')
    if [[ ! "$size_bytes" =~ ^[0-9]+$ ]]; then
        size_bytes=0
    fi
    
    size_mb=$((size_bytes / 1024 / 1024))

    if ! check_db_exists "$dbname"; then
        echo -e "${RED}✗ DB not exists on target: $dbname${NC}"
        echo -e "  ${YELLOW}Run create_databases_on_target.sh first!${NC}"
        echo "$dbname|$size_bytes" >> databases_not_exist.txt
        continue
    fi

    # Получить количество таблиц (основной критерий проверки)
    source_tables=$(get_table_count_local "$dbname")
    target_tables=$(get_table_count_remote "$dbname")

    if [ "$target_tables" = "0" ]; then
        # База пустая - переносим
        echo -e "${GREEN}→ Will migrate: $dbname (${size_mb} MB, $source_tables tables)${NC}"
        echo "$dbname|$size_bytes|$source_tables" >> databases_to_migrate.txt

    elif [ "$source_tables" = "$target_tables" ]; then
        # Количество таблиц совпадает - считаем полностью перенесенной
        echo -e "${YELLOW}⊙ Already migrated: $dbname (${size_mb} MB, $source_tables tables ✓)${NC}"
        echo "$dbname|$size_bytes" >> databases_already_migrated.txt

    else
        # Таблицы есть, но количество не совпадает - неполный перенос
        echo -e "${RED}⚠ Incomplete migration: $dbname (${size_mb} MB, source: $source_tables tables, target: $target_tables tables)${NC}"
        echo -e "  ${YELLOW}Database needs to be recreated manually${NC}"
        echo "$dbname|$size_bytes|$source_tables|$target_tables" >> databases_incomplete.txt
    fi

done < databases_filtered.txt

total=$(wc -l < databases_to_migrate.txt 2>/dev/null || echo 0)
migrated=$(wc -l < databases_already_migrated.txt 2>/dev/null || echo 0)
not_exist=$(wc -l < databases_not_exist.txt 2>/dev/null || echo 0)
incomplete=$(wc -l < databases_incomplete.txt 2>/dev/null || echo 0)

# ============================================
# SUMMARY И ПОДТВЕРЖДЕНИЕ
# ============================================

echo ""
echo "=== Summary ==="
echo "Databases to migrate: $total"
echo "Already migrated (complete): $migrated"
if [ $incomplete -gt 0 ]; then
    echo -e "${RED}Incomplete migrations (need manual fix): $incomplete${NC}"
fi
if [ $not_exist -gt 0 ]; then
    echo -e "${RED}Not exist on target: $not_exist${NC}"
    echo "Please run create_databases_on_target.sh first!"
    exit 1
fi
echo "Parallel jobs: $MAX_PARALLEL"
echo ""

# Показать детали неполных миграций
if [ $incomplete -gt 0 ]; then
    echo "=== Incomplete Databases (need manual fix) ==="
    while IFS='|' read -r dbname size_bytes source_tables target_tables; do
        echo -e "${YELLOW}  $dbname: source=$source_tables tables, target=$target_tables tables${NC}"
    done < databases_incomplete.txt
    echo ""
    echo "To fix incomplete databases:"
    echo "  psql -h $TARGET_HOST -U $TARGET_USER -d postgres -c 'DROP DATABASE \"dbname\"'"
    echo "  psql -h $TARGET_HOST -U $TARGET_USER -d postgres -c 'CREATE DATABASE \"dbname\" OWNER $TARGET_USER'"
    echo "  Then rerun this script"
    echo ""
fi

if [ $total -eq 0 ]; then
    if [ $incomplete -gt 0 ]; then
        echo -e "${YELLOW}No new databases to migrate, but $incomplete incomplete migrations need fixing.${NC}"
    else
        echo -e "${GREEN}✓ All databases already migrated!${NC}"
    fi
    exit 0
fi

read -p "Start migration of $total database(s)? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Migration cancelled."
    exit 0
fi

# ============================================
# МИГРАЦИЯ
# ============================================

echo ""
echo "Starting migration at: $(date)"
echo "========================================"

current=0

while IFS='|' read -r dbname size_bytes source_tables; do
    if [ -z "$dbname" ]; then continue; fi

    # Динамическая очередь: ждем освобождения слота
    # Проверяем и pg_dump и pg_restore процессы (оба могут работать параллельно)
    while true; do
        running_dumps=$(ps aux 2>/dev/null | grep -E "pg_dump -Fd|pg_restore" | grep -v grep | wc -l)
        if [ "$running_dumps" -lt "$MAX_PARALLEL" ]; then
            break
        fi
        sleep 2
    done

    ((current++))
    
    # Убираем пробелы и проверяем число
    size_bytes=$(echo "$size_bytes" | tr -d ' ')
    if [[ ! "$size_bytes" =~ ^[0-9]+$ ]]; then
        size_bytes=0
    fi
    size_mb=$((size_bytes / 1024 / 1024))

    # Определяем количество параллельных jobs для pg_dump/restore
    if [ $size_mb -gt 10000 ]; then
        jobs=4
    elif [ $size_mb -gt 5000 ]; then
        jobs=3
    elif [ $size_mb -gt 1000 ]; then
        jobs=2
    else
        jobs=1
    fi

    # Запуск в фоне (динамическая очередь)
    (
        start_time=$(date +%s)
        log_file="migration_logs/${dbname}.log"
        dump_path="$DUMP_DIR/${dbname}_dump"

        echo "[$current/$total] Starting: $dbname (${size_mb} MB, $source_tables tables, jobs=$jobs) at $(date)" | tee -a "$log_file"

        # ============================================
        # ШАГ 1: DUMP (локально, без -h и -U)
        # ============================================
        echo "  [1/2] Creating dump..." | tee -a "$log_file"
        if pg_dump -Fd \
            --no-owner --no-privileges \
            --compress=6 \
            --jobs=$jobs \
            -f "$dump_path" \
            "$dbname" >> "$log_file" 2>&1; then

            dump_size=$(du -sh "$dump_path" | cut -f1)
            echo "  [1/2] ✓ Dump completed: $dump_size" | tee -a "$log_file"
        else
            echo "[$current/$total] ✗ FAILED (dump): $dbname" | tee -a "$log_file" migration_logs/FAILED.log
            rm -rf "$dump_path"
            exit 1
        fi

        # ============================================
        # ШАГ 2: RESTORE (удаленно, с -h и -U)
        # ============================================
        echo "  [2/2] Restoring to target..." | tee -a "$log_file"
        if pg_restore -h $TARGET_HOST -U $TARGET_USER -d "$dbname" \
            --jobs=$jobs \
            --disable-triggers \
            --no-owner --no-privileges \
            "$dump_path" >> "$log_file" 2>&1; then

            end_time=$(date +%s)
            duration=$((end_time - start_time))
            minutes=$((duration / 60))
            seconds=$((duration % 60))

            # Получить размеры (только для информации, не для проверки)
            source_size=$(get_db_size_local "$dbname")
            target_size=$(get_db_size_remote "$dbname")
            source_mb=$((source_size / 1024 / 1024))
            target_mb=$((target_size / 1024 / 1024))

            # Проверка количества таблиц (основной критерий успеха)
            restored_tables=$(get_table_count_remote "$dbname")

            if [ "$source_tables" = "$restored_tables" ]; then
                echo "[$current/$total] ✓ SUCCESS: $dbname in ${minutes}m ${seconds}s" | tee -a "$log_file" migration_logs/SUCCESS.log
                echo "  Tables: $restored_tables/$source_tables ✓, Size: ${source_mb}MB → ${target_mb}MB" | tee -a "$log_file"
                
                # Принудительный CHECKPOINT на целевом сервере для очистки WAL
                echo "  [CHECKPOINT] Cleaning WAL on target server..." | tee -a "$log_file"
                psql -h $TARGET_HOST -U $TARGET_USER -d postgres -c "CHECKPOINT;" >> "$log_file" 2>&1 || echo "  [CHECKPOINT] Warning: checkpoint may have failed" | tee -a "$log_file"
            else
                echo "[$current/$total] ⚠ WARNING: $dbname completed but table count mismatch" | tee -a "$log_file" migration_logs/WARNING.log
                echo "  Tables: $restored_tables/$source_tables (source: $source_tables, target: $restored_tables)" | tee -a "$log_file"
            fi

            # Cleanup
            rm -rf "$dump_path"

        else
            echo "[$current/$total] ✗ FAILED (restore): $dbname" | tee -a "$log_file" migration_logs/FAILED.log
            echo "  Dump saved for analysis: $dump_path" | tee -a "$log_file"
            exit 1
        fi

    ) &  # Запуск в фоне

done < databases_to_migrate.txt

# ============================================
# ОЖИДАНИЕ ЗАВЕРШЕНИЯ И РЕЗУЛЬТАТЫ
# ============================================

echo ""
echo "Waiting for all migrations to complete..."
wait

echo ""
echo "========================================"
echo "Migration completed at: $(date)"

# Cleanup
echo "Cleaning up temporary dumps..."
rm -rf "$DUMP_DIR"/*

success=$(grep -c "SUCCESS" migration_logs/SUCCESS.log 2>/dev/null || echo 0)
warnings=$(grep -c "WARNING" migration_logs/WARNING.log 2>/dev/null || echo 0)
failed=$(grep -c "FAILED" migration_logs/FAILED.log 2>/dev/null || echo 0)

echo ""
echo "=== Results ==="
echo -e "${GREEN}Successfully migrated: $success${NC}"
if [ $warnings -gt 0 ]; then
    echo -e "${YELLOW}Completed with warnings (table count mismatch): $warnings${NC}"
    echo "Check migration_logs/WARNING.log for details"
fi
if [ $failed -gt 0 ]; then
    echo -e "${RED}Failed: $failed${NC}"
    echo "Check migration_logs/FAILED.log for details"
fi

echo ""
echo "=== Total Size Comparison ==="
echo "Source (local):"
psql -c \
  "SELECT pg_size_pretty(sum(pg_database_size(datname)))
   FROM pg_database WHERE datistemplate = false AND datname != 'postgres'"

echo "Target ($TARGET_HOST):"
psql -h $TARGET_HOST -U $TARGET_USER -d postgres -c \
  "SELECT pg_size_pretty(sum(pg_database_size(datname)))
   FROM pg_database WHERE datistemplate = false AND datname != 'postgres'"

echo ""
echo "=== IMPORTANT ==="
echo -e "${YELLOW}Don't forget to remove password from scripts after migration!${NC}"
