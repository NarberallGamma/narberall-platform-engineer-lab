#!/bin/bash
# check_databases_size.sh
# Скрипт для проверки размера баз данных и количества таблиц
# Подключение через peer authentication (как postgres пользователь на localhost)
# Usage: ./check_databases_size.sh [dblist_file.txt]
#   Если указан файл со списком БД - проверит только указанные БД из списка

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

DB_LIST_FILE="$1"

# ============================================
# ПРОВЕРКА ПОДКЛЮЧЕНИЯ
# ============================================

echo "=== Database Size Check Tool ==="
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
    
    > databases_to_check.txt
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
            echo "$requested_db" >> databases_to_check.txt
            ((found_count++))
        else
            echo -e "${RED}✗ Database not found: $requested_db${NC}"
            # Отладочный вывод - проверим что есть в базе (поиск похожих имен)
            escaped_pattern=$(printf '%s' "$requested_db" | sed "s/'/''/g")
            similar=$(psql -d postgres -tAc \
                "SELECT datname FROM pg_database WHERE datname LIKE '%$escaped_pattern%' LIMIT 1" 2>/dev/null | xargs)
            if [ -n "$similar" ] && [ "$similar" != "$requested_db" ]; then
                echo -e "${YELLOW}  (Found similar in DB: $similar)${NC}"
            fi
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
            rm -f /tmp/all_available_dbs.txt /tmp/missing_dbs.txt
            exit 1
        fi
        echo ""
    fi
    
    rm -f /tmp/all_available_dbs.txt /tmp/missing_dbs.txt
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
       ORDER BY datname" > databases_to_check.txt
fi

db_count=$(wc -l < databases_to_check.txt 2>/dev/null | xargs)

if [ "$db_count" -eq 0 ]; then
    echo -e "${YELLOW}No databases found to check${NC}"
    exit 0
fi

# ============================================
# ФУНКЦИИ
# ============================================

get_db_size() {
    local dbname=$1
    psql -d postgres -tAc "SELECT pg_database_size('$dbname')" 2>/dev/null || echo "0"
}

get_table_count() {
    local dbname=$1
    psql -d "$dbname" -tAc \
        "SELECT count(*) FROM information_schema.tables WHERE table_schema='public'" 2>/dev/null || echo "0"
}

format_size() {
    local bytes=$1
    local gb=$((bytes / 1024 / 1024 / 1024))
    local mb=$((bytes / 1024 / 1024))
    
    if [ $gb -gt 0 ]; then
        local mb_remainder=$(((bytes / 1024 / 1024) % 1024))
        echo "${gb}.${mb_remainder} GB"
    else
        echo "${mb} MB"
    fi
}

# ============================================
# СБОР ДАННЫХ
# ============================================

echo ""
echo "=== Collecting database information ==="
echo "Checking $db_count database(s)..."
echo ""

total_size=0
> /tmp/db_info.txt

while IFS= read -r dbname; do
    if [ -z "$dbname" ]; then continue; fi
    
    echo -n "Checking $dbname... "
    
    size_bytes=$(get_db_size "$dbname")
    table_count=$(get_table_count "$dbname")
    
    if [[ "$size_bytes" =~ ^[0-9]+$ ]]; then
        total_size=$((total_size + size_bytes))
        echo "$dbname|$size_bytes|$table_count" >> /tmp/db_info.txt
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗ (error)${NC}"
    fi
done < databases_to_check.txt

# ============================================
# ВЫВОД РЕЗУЛЬТАТОВ
# ============================================

echo ""
echo "========================================"
echo "=== Database Size Report ==="
echo "========================================"
echo ""

# Таблица с результатами
printf "%-30s %15s %10s\n" "Database Name" "Size" "Tables"
echo "----------------------------------------------------------------"

while IFS='|' read -r dbname size_bytes table_count; do
    if [ -z "$dbname" ]; then continue; fi
    
    size_display=$(format_size "$size_bytes")
    printf "%-30s %15s %10s\n" "$dbname" "$size_display" "$table_count"
done < /tmp/db_info.txt

echo "----------------------------------------------------------------"
total_size_display=$(format_size "$total_size")
printf "%-30s %15s %10s\n" "TOTAL" "$total_size_display" "-"
echo ""

# Дополнительная статистика
echo "=== Statistics ==="
total_tables=0
while IFS='|' read -r dbname size_bytes table_count; do
    if [ -z "$dbname" ]; then continue; fi
    total_tables=$((total_tables + table_count))
done < /tmp/db_info.txt

echo "Total databases: $db_count"
echo "Total size: $total_size_display"
echo "Total tables: $total_tables"
avg_size=$((total_size / db_count))
avg_size_display=$(format_size "$avg_size")
echo "Average database size: $avg_size_display"

# Топ-5 самых больших БД
echo ""
echo "=== Top 5 Largest Databases ==="
sort -t'|' -k2 -rn /tmp/db_info.txt | head -5 | while IFS='|' read -r dbname size_bytes table_count; do
    size_display=$(format_size "$size_bytes")
    printf "  %-30s %15s (%s tables)\n" "$dbname" "$size_display" "$table_count"
done

echo ""
echo "Done!"

# Cleanup
rm -f /tmp/db_info.txt databases_to_check.txt

