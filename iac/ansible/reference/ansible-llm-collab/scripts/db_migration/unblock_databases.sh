#!/bin/bash
# unblock_databases.sh
# Скрипт для разблокировки баз данных PostgreSQL
# Подключение через peer authentication (как postgres пользователь на localhost)
# Usage: ./unblock_databases.sh [read_only|full] [dblist_file.txt]
#   read_only - разблокировать write операции (убрать read-only режим)
#   full - разрешить подключения (убрать полную блокировку)
#   Если указан файл со списком БД - будет разблокировать только указанные БД из списка

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

UNBLOCK_MODE="$1"  # read_only или full
DB_LIST_FILE="$2"

# Проверка параметров
if [ "$UNBLOCK_MODE" != "read_only" ] && [ "$UNBLOCK_MODE" != "full" ]; then
    echo "Usage: $0 [read_only|full] [dblist_file.txt]"
    echo ""
    echo "Modes:"
    echo "  read_only - Unblock write operations (remove read-only mode)"
    echo "  full      - Allow connections (remove full block)"
    echo ""
    echo "Examples:"
    echo "  $0 read_only                           # Unblock all read-only databases"
    echo "  $0 read_only dblist.txt                # Unblock specific databases"
    echo "  $0 full                                # Unblock all blocked databases"
    echo "  $0 full dblist.txt                     # Unblock specific databases"
    exit 1
fi

# ============================================
# ПРОВЕРКА ПОДКЛЮЧЕНИЯ
# ============================================

echo "=== Database Unblocking Tool ==="
echo "Mode: $UNBLOCK_MODE"
if [ "$UNBLOCK_MODE" = "read_only" ]; then
    echo "Action: Remove READ-ONLY mode (allow write operations)"
else
    echo "Action: Allow connections (remove block)"
fi
if [ -n "$DB_LIST_FILE" ]; then
    echo "Using database list from file: $DB_LIST_FILE"
else
    echo "Processing all databases (except system)"
fi
echo ""

# Проверка подключения к PostgreSQL
if ! psql -d postgres -c "SELECT 1" >/dev/null 2>&1; then
    echo -e "${RED}Error: Cannot connect to PostgreSQL!${NC}"
    echo "Make sure you are running as postgres user with peer authentication enabled."
    exit 1
fi

# Получить версию PostgreSQL
pg_version=$(psql -d postgres -tAc "SELECT version();" 2>/dev/null | head -n1)
echo -e "${GREEN}✓ Connected to PostgreSQL${NC}"
echo "  Version: $pg_version"
echo ""

# ============================================
# ПОЛУЧЕНИЕ СПИСКА БАЗ ДАННЫХ
# ============================================

if [ -n "$DB_LIST_FILE" ]; then
    if [ ! -f "$DB_LIST_FILE" ]; then
        echo -e "${RED}Error: File '$DB_LIST_FILE' not found!${NC}"
        exit 1
    fi
    
    echo "Reading database list from file: $DB_LIST_FILE"
    
    > databases_to_unblock.txt
    found_count=0
    not_found_count=0
    
    # Проверить каждую БД из списка
    while IFS= read -r requested_db || [ -n "$requested_db" ]; do
        # Пропускаем пустые строки и комментарии, очищаем от пробелов и невидимых символов
        requested_db=$(echo "$requested_db" | sed 's/#.*$//' | tr -d '\r\n' | xargs)
        if [ -z "$requested_db" ]; then continue; fi
        
        # Экранируем одинарные кавычки в имени БД для SQL (удваиваем их)
        escaped_db=$(printf '%s' "$requested_db" | sed "s/'/''/g")
        
        # Проверить существование БД через SQL запрос
        db_exists=$(psql -d postgres -tAc \
            "SELECT 1 FROM pg_database WHERE datname = '$escaped_db'" 2>/dev/null | tr -d '[:space:]')
        
        if [ "$db_exists" = "1" ]; then
            echo "$requested_db" >> databases_to_unblock.txt
            ((found_count++))
        else
            echo -e "${RED}✗ Database not found: $requested_db${NC}"
            ((not_found_count++))
        fi
    done < "$DB_LIST_FILE"
    
    if [ $not_found_count -gt 0 ]; then
        echo ""
        echo "=== Validation Results ==="
        echo -e "${GREEN}Found: $found_count${NC}"
        echo -e "${RED}Not found: $not_found_count${NC}"
        if [ $found_count -eq 0 ]; then
            echo -e "${RED}No valid databases found!${NC}"
            exit 1
        fi
        echo ""
    fi
else
    # Получить все БД (кроме системных)
    echo "Fetching database list from server..."
    psql -d postgres -tAc \
      "SELECT datname
       FROM pg_database
       WHERE datistemplate = false
       AND datname != 'postgres'
       AND datname NOT LIKE '%Test%'
       AND datname NOT LIKE '?%'
       ORDER BY datname" > databases_to_unblock.txt
fi

db_count=$(wc -l < databases_to_unblock.txt 2>/dev/null | xargs)

if [ "$db_count" -eq 0 ]; then
    echo -e "${YELLOW}No databases found to unblock${NC}"
    exit 0
fi

# ============================================
# ФУНКЦИИ
# ============================================

get_db_current_state() {
    local dbname=$1
    local mode=$2
    
    if [ "$mode" = "read_only" ]; then
        # Проверить read-only статус
        local state=$(psql -d postgres -tAc \
            "SELECT CASE WHEN datconfig IS NULL THEN 'writable'
                        WHEN datconfig::text LIKE '%default_transaction_read_only%' THEN 'read_only'
                        ELSE 'writable' END
             FROM pg_database WHERE datname = '$dbname'" 2>/dev/null)
        echo "$state"
    else
        # Проверить allow_connections
        local state=$(psql -d postgres -tAc \
            "SELECT CASE WHEN datallowconn = true THEN 'allowed'
                        ELSE 'blocked' END
             FROM pg_database WHERE datname = '$dbname'" 2>/dev/null)
        echo "$state"
    fi
}

unblock_database_read_only() {
    local dbname=$1
    local escaped_db=$(printf '%s' "$dbname" | sed "s/'/''/g")
    
    psql -d postgres -c \
        "ALTER DATABASE \"$escaped_db\" RESET default_transaction_read_only" >/dev/null 2>&1
}

unblock_database_full() {
    local dbname=$1
    local escaped_db=$(printf '%s' "$dbname" | sed "s/'/''/g")
    
    psql -d postgres -c \
        "ALTER DATABASE \"$escaped_db\" WITH allow_connections = true" >/dev/null 2>&1
}

# ============================================
# ПРЕДВАРИТЕЛЬНЫЙ ПРОСМОТР
# ============================================

echo ""
echo "=== Databases to unblock ==="
echo ""

total=0
already_unblocked=0
need_unblock=0

> databases_need_unblock.txt

while IFS= read -r dbname; do
    if [ -z "$dbname" ]; then continue; fi
    ((total++))
    
    current_state=$(get_db_current_state "$dbname" "$UNBLOCK_MODE")
    
    if [ "$UNBLOCK_MODE" = "read_only" ]; then
        if [ "$current_state" = "writable" ]; then
            echo -e "${YELLOW}⊙ $dbname (already writable)${NC}"
            ((already_unblocked++))
        else
            echo -e "${GREEN}→ $dbname (current: read-only → new: writable)${NC}"
            echo "$dbname" >> databases_need_unblock.txt
            ((need_unblock++))
        fi
    else
        if [ "$current_state" = "allowed" ]; then
            echo -e "${YELLOW}⊙ $dbname (already allowed)${NC}"
            ((already_unblocked++))
        else
            echo -e "${GREEN}→ $dbname (current: blocked → new: allowed)${NC}"
            echo "$dbname" >> databases_need_unblock.txt
            ((need_unblock++))
        fi
    fi
done < databases_to_unblock.txt

echo ""
echo "=== Summary ==="
echo "Total databases: $total"
echo -e "${YELLOW}Already unblocked: $already_unblocked${NC}"
echo -e "${GREEN}Need to unblock: $need_unblock${NC}"
echo ""

if [ $need_unblock -eq 0 ]; then
    echo -e "${GREEN}All databases already unblocked!${NC}"
    exit 0
fi

# ============================================
# ПОДТВЕРЖДЕНИЕ
# ============================================

read -p "Unblock $need_unblock database(s)? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Cancelled."
    exit 0
fi

# ============================================
# РАЗБЛОКИРОВКА
# ============================================

echo ""
echo "=== Unblocking databases ==="
echo ""

success=0
failed=0

while IFS= read -r dbname; do
    if [ -z "$dbname" ]; then continue; fi
    
    echo -n "Unblocking $dbname... "
    
    if [ "$UNBLOCK_MODE" = "read_only" ]; then
        if unblock_database_read_only "$dbname"; then
            echo -e "${GREEN}✓${NC}"
            ((success++))
        else
            echo -e "${RED}✗${NC}"
            ((failed++))
        fi
    else
        if unblock_database_full "$dbname"; then
            echo -e "${GREEN}✓${NC}"
            ((success++))
        else
            echo -e "${RED}✗${NC}"
            ((failed++))
        fi
    fi
done < databases_need_unblock.txt

# ============================================
# РЕЗУЛЬТАТЫ
# ============================================

echo ""
echo "=== Results ==="
echo -e "${GREEN}Successfully unblocked: $success${NC}"
if [ $failed -gt 0 ]; then
    echo -e "${RED}Failed: $failed${NC}"
fi

echo ""
echo "Done!"

# Cleanup
rm -f databases_to_unblock.txt databases_need_unblock.txt

