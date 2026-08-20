#!/bin/bash
# create_databases_on_target_server.sh
# Usage: ./create_databases_on_target_server.sh [dblist_file.txt]
#   Если указан файл со списком БД - будет создавать только указанные БД из списка

TARGET_HOST="10.10.2.251"
TARGET_USER="svc_postgres_1c"
TARGET_PASSWORD=:""  # УДАЛИТЬ ПОСЛЕ ЗАВЕРШЕНИЯ!
DB_OWNER="svc_postgres_1c"  # Владелец для ВСЕХ баз

export PGPASSWORD="$TARGET_PASSWORD"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

DB_LIST_FILE="$1"

echo "=== Pre-create databases on target server ==="
echo "Target: $TARGET_HOST"
echo "Database owner: $DB_OWNER (for all databases)"
if [ -n "$DB_LIST_FILE" ]; then
    echo "Using database list from file: $DB_LIST_FILE"
fi
echo ""

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

# Если передан файл со списком БД
if [ -n "$DB_LIST_FILE" ]; then
    if [ ! -f "$DB_LIST_FILE" ]; then
        echo -e "${RED}Error: File '$DB_LIST_FILE' not found!${NC}"
        exit 1
    fi
    
    echo "Reading database list from file: $DB_LIST_FILE"
    echo "Validating databases exist in source server..."
    
    # Получить все доступные БД из исходной СУБД
    psql -t -A -c \
      "SELECT datname
       FROM pg_database
       WHERE datistemplate = false
       AND datname != 'postgres'" > /tmp/all_available_dbs.txt
    
    > databases_list.txt
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
            # БД существует, получить размер
            size_bytes=$(psql -t -A -c "SELECT pg_database_size('$escaped_db')" 2>/dev/null | xargs)
            echo "$requested_db|$size_bytes" >> databases_list.txt
            ((found_count++))
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
    
    # Сортировка по размеру (от больших к маленьким)
    sort -t'|' -k2 -rn databases_list.txt > databases_list_sorted.txt
    mv databases_list_sorted.txt databases_list.txt
    
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
       ORDER BY pg_database_size(datname) DESC" > databases_list.txt
fi

# Показать какие базы будут созданы
echo ""
echo "=== Databases to create ==="
total=0
exists=0
create=0

> databases_to_create.txt

while IFS='|' read -r dbname size_bytes; do
    if [ -z "$dbname" ]; then continue; fi
    ((total++))

    # Убираем пробелы из size_bytes и проверяем что это число
    size_bytes=$(echo "$size_bytes" | tr -d ' ')
    if [[ ! "$size_bytes" =~ ^[0-9]+$ ]]; then
        size_bytes=0
    fi

    size_mb=$((size_bytes / 1024 / 1024))
    size_gb=$((size_mb / 1024))

    # Показываем в GB если больше 1024 MB
    if [ $size_gb -gt 0 ]; then
        size_display="${size_gb} GB"
    else
        size_display="${size_mb} MB"
    fi

    # Проверить существование базы на целевом (ДОБАВЛЕНО: -d postgres)
    db_exists=$(psql -h $TARGET_HOST -U $TARGET_USER -d postgres -tAc \
        "SELECT 1 FROM pg_database WHERE datname='$dbname'" 2>/dev/null)

    if [ "$db_exists" = "1" ]; then
        ((exists++))
        echo -e "${YELLOW}⊙ Already exists: $dbname ($size_display)${NC}"
    else
        ((create++))
        echo -e "${GREEN}→ Will create: $dbname ($size_display, owner: $DB_OWNER)${NC}"
        echo "$dbname" >> databases_to_create.txt
    fi
done < databases_list.txt

echo ""
echo "=== Summary ==="
echo "Total databases: $total"
echo "Already exist: $exists"
echo "To create: $create"
echo "Owner for all new databases: $DB_OWNER"
echo ""

if [ $create -eq 0 ]; then
    echo -e "${GREEN}All databases already exist on target!${NC}"
    exit 0
fi

read -p "Create $create databases on target? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo "=== Creating databases ==="

success=0
failed=0

while read -r dbname; do
    if [ -z "$dbname" ]; then continue; fi

    echo -n "Creating: $dbname (owner: $DB_OWNER)... "

    # Создать базу с указанным владельцем (ДОБАВЛЕНО: -d postgres)
    if psql -h $TARGET_HOST -U $TARGET_USER -d postgres -c \
        "CREATE DATABASE \"$dbname\" OWNER \"$DB_OWNER\"" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        ((success++))
    else
        echo -e "${RED}✗${NC}"
        ((failed++))
    fi

done < databases_to_create.txt

echo ""
echo "=== Results ==="
echo -e "${GREEN}Successfully created: $success${NC}"
if [ $failed -gt 0 ]; then
    echo -e "${RED}Failed: $failed${NC}"
fi

echo ""
echo "Done! Now you can run the migration script."
