#!/bin/bash
# change_databases_owner.sh
# Скрипт для смены владельца (owner) баз данных на целевом сервере
# Использует peer authentication (подключение как postgres пользователь на localhost)
# Usage: ./change_databases_owner.sh [dblist_file.txt]
#   Если указан файл со списком БД - будет менять owner только у указанных БД

# ============================================
# НАСТРОЙКИ
# ============================================
NEW_OWNER="svc_postgres_1c"  # Новый владелец для БД
NEW_OWNER_PASSWORD=""         # Пароль для нового пользователя (если нужно создать)
# Если NEW_OWNER_PASSWORD пуст - пароль будет запрошен интерактивно при создании пользователя

# Опционально: автоматически создавать пользователя если его нет
AUTO_CREATE_USER=false        # true - создавать автоматически, false - спрашивать

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

DB_LIST_FILE="$1"

# ============================================
# ФУНКЦИИ
# ============================================

check_user_exists() {
    local username=$1
    local exists=$(psql -d postgres -tAc \
        "SELECT 1 FROM pg_roles WHERE rolname='$username'" 2>/dev/null)
    [ "$exists" = "1" ] && return 0 || return 1
}

get_db_current_owner() {
    local dbname=$1
    psql -d postgres -tAc \
        "SELECT pg_catalog.pg_get_userbyid(datdba) FROM pg_database WHERE datname='$dbname'" 2>/dev/null
}

create_user() {
    local username=$1
    local password=$2
    
    if [ -n "$password" ]; then
        # Используем экранирование пароля для безопасности
        psql -d postgres -c \
            "CREATE USER \"$username\" WITH PASSWORD '$password'" >/dev/null 2>&1
        return $?
    else
        # Интерактивный ввод пароля - используем read для безопасного ввода
        return 1  # Не должно вызываться без пароля
    fi
}

change_db_owner() {
    local dbname=$1
    local new_owner=$2
    
    psql -d postgres -c \
        "ALTER DATABASE \"$dbname\" OWNER TO \"$new_owner\"" >/dev/null 2>&1
}

# ============================================
# ПРОВЕРКА ПОДКЛЮЧЕНИЯ
# ============================================

echo "=== Change Databases Owner Tool ==="
echo "New owner: $NEW_OWNER"
if [ -n "$DB_LIST_FILE" ]; then
    echo "Using database list from file: $DB_LIST_FILE"
fi
echo ""

# Проверка подключения к PostgreSQL
if ! psql -d postgres -c "SELECT 1" >/dev/null 2>&1; then
    echo -e "${RED}Error: Cannot connect to PostgreSQL!${NC}"
    echo "Make sure you are running as postgres user with peer authentication enabled."
    exit 1
fi

# ============================================
# ПРОВЕРКА И СОЗДАНИЕ ПОЛЬЗОВАТЕЛЯ
# ============================================

if ! check_user_exists "$NEW_OWNER"; then
    echo -e "${YELLOW}User '$NEW_OWNER' does not exist!${NC}"
    
    if [ "$AUTO_CREATE_USER" = "true" ]; then
        create_user_choice="yes"
    else
        read -p "Create user '$NEW_OWNER'? (yes/no): " create_user_choice
    fi
    
    if [ "$create_user_choice" = "yes" ]; then
        echo "Creating user '$NEW_OWNER'..."
        
        if [ -z "$NEW_OWNER_PASSWORD" ]; then
            # Интерактивный ввод пароля
            read -sp "Enter password for user '$NEW_OWNER': " password_input
            echo ""
            read -sp "Confirm password: " password_confirm
            echo ""
            
            if [ "$password_input" != "$password_confirm" ]; then
                echo -e "${RED}Passwords do not match!${NC}"
                exit 1
            fi
            
            if [ -z "$password_input" ]; then
                echo -e "${RED}Password cannot be empty!${NC}"
                exit 1
            fi
            
            NEW_OWNER_PASSWORD="$password_input"
        fi
        
        if create_user "$NEW_OWNER" "$NEW_OWNER_PASSWORD"; then
            echo -e "${GREEN}✓ User '$NEW_OWNER' created successfully${NC}"
        else
            echo -e "${RED}✗ Failed to create user '$NEW_OWNER'${NC}"
            exit 1
        fi
    else
        echo "Cannot proceed without user. Exiting."
        exit 1
    fi
else
    echo -e "${GREEN}✓ User '$NEW_OWNER' exists${NC}"
fi

# ============================================
# ПОЛУЧЕНИЕ СПИСКА БАЗ ДАННЫХ
# ============================================

echo ""
echo "Fetching database list..."

if [ -n "$DB_LIST_FILE" ]; then
    if [ ! -f "$DB_LIST_FILE" ]; then
        echo -e "${RED}Error: File '$DB_LIST_FILE' not found!${NC}"
        exit 1
    fi
    
    echo "Reading database list from file: $DB_LIST_FILE"
    
    # Получить все доступные БД
    psql -d postgres -tAc \
      "SELECT datname
       FROM pg_database
       WHERE datistemplate = false
       AND datname != 'postgres'" > /tmp/all_available_dbs.txt
    
    > databases_to_change.txt
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
            echo "$requested_db" >> databases_to_change.txt
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
            rm -f /tmp/all_available_dbs.txt /tmp/missing_dbs.txt
            exit 1
        fi
        echo ""
        read -p "Continue with found databases only? (yes/no): " confirm_continue
        if [ "$confirm_continue" != "yes" ]; then
            echo "Cancelled."
            rm -f /tmp/all_available_dbs.txt /tmp/missing_dbs.txt
            exit 0
        fi
    fi
    
    rm -f /tmp/all_available_dbs.txt /tmp/missing_dbs.txt
else
    # Получить все БД (кроме системных)
    psql -d postgres -tAc \
      "SELECT datname
       FROM pg_database
       WHERE datistemplate = false
       AND datname != 'postgres'
       AND datname NOT LIKE '%Test%'
       AND datname NOT LIKE '?%'
       ORDER BY datname" > databases_to_change.txt
fi

db_count=$(wc -l < databases_to_change.txt 2>/dev/null | xargs)

if [ "$db_count" -eq 0 ]; then
    echo -e "${YELLOW}No databases found to change owner${NC}"
    exit 0
fi

# ============================================
# ПРЕДВАРИТЕЛЬНЫЙ ПРОСМОТР
# ============================================

echo ""
echo "=== Databases to change owner ==="
echo "New owner: $NEW_OWNER"
echo ""

total=0
already_correct=0
need_change=0

> databases_need_change.txt

while IFS= read -r dbname; do
    if [ -z "$dbname" ]; then continue; fi
    ((total++))
    
    current_owner=$(get_db_current_owner "$dbname")
    
    if [ "$current_owner" = "$NEW_OWNER" ]; then
        echo -e "${YELLOW}⊙ $dbname (current owner: $current_owner - already correct)${NC}"
        ((already_correct++))
    else
        echo -e "${GREEN}→ $dbname (current: $current_owner → new: $NEW_OWNER)${NC}"
        echo "$dbname|$current_owner" >> databases_need_change.txt
        ((need_change++))
    fi
done < databases_to_change.txt

echo ""
echo "=== Summary ==="
echo "Total databases: $total"
echo -e "${YELLOW}Already have correct owner: $already_correct${NC}"
echo -e "${GREEN}Need to change owner: $need_change${NC}"
echo ""

if [ $need_change -eq 0 ]; then
    echo -e "${GREEN}All databases already have correct owner!${NC}"
    exit 0
fi

# ============================================
# ПОДТВЕРЖДЕНИЕ
# ============================================

read -p "Change owner for $need_change database(s)? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Cancelled."
    exit 0
fi

# ============================================
# СМЕНА OWNER
# ============================================

echo ""
echo "=== Changing database owners ==="
echo ""

success=0
failed=0

while IFS='|' read -r dbname current_owner; do
    if [ -z "$dbname" ]; then continue; fi
    
    echo -n "Changing $dbname (from $current_owner to $NEW_OWNER)... "
    
    if change_db_owner "$dbname" "$NEW_OWNER"; then
        echo -e "${GREEN}✓${NC}"
        ((success++))
    else
        echo -e "${RED}✗${NC}"
        ((failed++))
    fi
done < databases_need_change.txt

# ============================================
# РЕЗУЛЬТАТЫ
# ============================================

echo ""
echo "=== Results ==="
echo -e "${GREEN}Successfully changed: $success${NC}"
if [ $failed -gt 0 ]; then
    echo -e "${RED}Failed: $failed${NC}"
fi

echo ""
echo "Done!"

