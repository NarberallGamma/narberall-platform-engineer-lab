#!/bin/bash
# block_databases.sh
# Скрипт для блокировки баз данных PostgreSQL
# Подключение через peer authentication (как postgres пользователь на localhost)
# Usage: ./block_databases.sh [read_only|full] [dblist_file.txt]
#   read_only - блокировка только на запись (read-only режим)
#   full - полная блокировка (read + write)
#   Если указан файл со списком БД - будет блокировать только указанные БД из списка

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

BLOCK_MODE="$1"  # read_only или full
DB_LIST_FILE="$2"

# Проверка параметров
if [ "$BLOCK_MODE" != "read_only" ] && [ "$BLOCK_MODE" != "full" ]; then
    echo "Usage: $0 [read_only|full] [dblist_file.txt]"
    echo ""
    echo "Modes:"
    echo "  read_only - Block write operations (read-only mode)"
    echo "  full      - Block all connections (read + write)"
    echo ""
    echo "Examples:"
    echo "  $0 read_only                           # Make all databases read-only"
    echo "  $0 read_only dblist.txt                # Make specific databases read-only"
    echo "  $0 full                                # Block all databases completely"
    echo "  $0 full dblist.txt                     # Block specific databases completely"
    exit 1
fi

# ============================================
# ПРОВЕРКА ПОДКЛЮЧЕНИЯ
# ============================================

echo "=== Database Blocking Tool ==="
echo "Mode: $BLOCK_MODE"
if [ "$BLOCK_MODE" = "read_only" ]; then
    echo "Action: Set databases to READ-ONLY (blocks write operations)"
else
    echo "Action: Block all connections (read + write)"
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
    
    > databases_to_block.txt
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
        db_exists=$(psql -d postgres -tAc \
            "SELECT 1 FROM pg_database WHERE datname = '$escaped_db'" 2>/dev/null | tr -d '[:space:]')
        
        if [ "$db_exists" = "1" ]; then
            echo "$requested_db" >> databases_to_block.txt
            ((found_count++))
        else
            echo -e "${RED}✗ Database not found: $requested_db${NC}"
            echo "$requested_db" >> /tmp/missing_dbs.txt
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
            rm -f /tmp/missing_dbs.txt
            exit 1
        fi
        echo ""
    fi
    
    rm -f /tmp/missing_dbs.txt
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
       ORDER BY datname" > databases_to_block.txt
fi

db_count=$(wc -l < databases_to_block.txt 2>/dev/null | xargs)

if [ "$db_count" -eq 0 ]; then
    echo -e "${YELLOW}No databases found to block${NC}"
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

block_database_read_only() {
    local dbname=$1
    local escaped_db=$(printf '%s' "$dbname" | sed "s/'/''/g")
    
    psql -d postgres -c \
        "ALTER DATABASE \"$escaped_db\" SET default_transaction_read_only = true" >/dev/null 2>&1
}

unblock_database_read_only() {
    local dbname=$1
    local escaped_db=$(printf '%s' "$dbname" | sed "s/'/''/g")
    
    psql -d postgres -c \
        "ALTER DATABASE \"$escaped_db\" RESET default_transaction_read_only" >/dev/null 2>&1
}

block_database_full() {
    local dbname=$1
    local escaped_db=$(printf '%s' "$dbname" | sed "s/'/''/g")
    
    psql -d postgres -c \
        "ALTER DATABASE \"$escaped_db\" WITH allow_connections = false" >/dev/null 2>&1
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
echo "=== Databases to block ==="
echo ""

total=0
already_blocked=0
need_block=0

> databases_need_block.txt

while IFS= read -r dbname; do
    if [ -z "$dbname" ]; then continue; fi
    ((total++))
    
    current_state=$(get_db_current_state "$dbname" "$BLOCK_MODE")
    
    if [ "$BLOCK_MODE" = "read_only" ]; then
        if [ "$current_state" = "read_only" ]; then
            echo -e "${YELLOW}⊙ $dbname (already read-only)${NC}"
            ((already_blocked++))
        else
            echo -e "${GREEN}→ $dbname (current: writable → new: read-only)${NC}"
            echo "$dbname" >> databases_need_block.txt
            ((need_block++))
        fi
    else
        if [ "$current_state" = "blocked" ]; then
            echo -e "${YELLOW}⊙ $dbname (already blocked)${NC}"
            ((already_blocked++))
        else
            echo -e "${GREEN}→ $dbname (current: allowed → new: blocked)${NC}"
            echo "$dbname" >> databases_need_block.txt
            ((need_block++))
        fi
    fi
done < databases_to_block.txt

echo ""
echo "=== Summary ==="
echo "Total databases: $total"
echo -e "${YELLOW}Already blocked: $already_blocked${NC}"
echo -e "${GREEN}Need to block: $need_block${NC}"
echo ""

if [ $need_block -eq 0 ]; then
    echo -e "${GREEN}All databases already blocked!${NC}"
    exit 0
fi

# ============================================
# ПОДТВЕРЖДЕНИЕ
# ============================================

if [ "$BLOCK_MODE" = "read_only" ]; then
    echo -e "${YELLOW}WARNING: This will set $need_block database(s) to READ-ONLY mode.${NC}"
    echo "Users will be able to read data but cannot write."
else
    echo -e "${RED}WARNING: This will BLOCK all connections to $need_block database(s).${NC}"
    echo "Users will NOT be able to connect to these databases at all."
fi
echo ""

read -p "Block $need_block database(s)? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Cancelled."
    exit 0
fi

# ============================================
# БЛОКИРОВКА
# ============================================

echo ""
echo "=== Blocking databases ==="
echo ""

success=0
failed=0

while IFS= read -r dbname; do
    if [ -z "$dbname" ]; then continue; fi
    
    echo -n "Blocking $dbname... "
    
    if [ "$BLOCK_MODE" = "read_only" ]; then
        if block_database_read_only "$dbname"; then
            echo -e "${GREEN}✓${NC}"
            ((success++))
        else
            echo -e "${RED}✗${NC}"
            ((failed++))
        fi
    else
        if block_database_full "$dbname"; then
            echo -e "${GREEN}✓${NC}"
            ((success++))
        else
            echo -e "${RED}✗${NC}"
            ((failed++))
        fi
    fi
done < databases_need_block.txt

# ============================================
# РЕЗУЛЬТАТЫ
# ============================================

echo ""
echo "=== Results ==="
echo -e "${GREEN}Successfully blocked: $success${NC}"
if [ $failed -gt 0 ]; then
    echo -e "${RED}Failed: $failed${NC}"
fi

echo ""
if [ "$BLOCK_MODE" = "read_only" ]; then
    echo "Databases are now in READ-ONLY mode."
    echo "To unblock, use: ALTER DATABASE dbname RESET default_transaction_read_only;"
else
    echo "Databases are now BLOCKED (no connections allowed)."
    echo "To unblock, use: ALTER DATABASE dbname WITH allow_connections = true;"
fi

echo ""
echo "Done!"

# Cleanup
rm -f databases_to_block.txt databases_need_block.txt

