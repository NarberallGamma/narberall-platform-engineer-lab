#!/bin/bash
# change_databases_owner.sh
# Script to change the owner of databases on the target server
# Uses peer authentication (connect as the postgres user on localhost)
# Usage: ./change_databases_owner.sh [dblist_file.txt]
#   When a list file is passed, only listed databases change owner

# ============================================
# SETTINGS
# ============================================
NEW_OWNER="svc_postgres_1c"  # new database owner
NEW_OWNER_PASSWORD=""         # password for a new role (if it must be created)
# When NEW_OWNER_PASSWORD is empty, the password is prompted interactively when creating the role

# Optional: create the role automatically when missing
AUTO_CREATE_USER=false        # true - create automatically, false - ask

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

DB_LIST_FILE="$1"

# ============================================
# FUNCTIONS
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
        # Escape the password for safety
        psql -d postgres -c \
            "CREATE USER \"$username\" WITH PASSWORD '$password'" >/dev/null 2>&1
        return $?
    else
        # Interactive password prompt - use read for safe input
        return 1  # must not be called without a password
    fi
}

change_db_owner() {
    local dbname=$1
    local new_owner=$2
    
    psql -d postgres -c \
        "ALTER DATABASE \"$dbname\" OWNER TO \"$new_owner\"" >/dev/null 2>&1
}

# ============================================
# CONNECTION CHECK
# ============================================

echo "=== Change Databases Owner Tool ==="
echo "New owner: $NEW_OWNER"
if [ -n "$DB_LIST_FILE" ]; then
    echo "Using database list from file: $DB_LIST_FILE"
fi
echo ""

# Check PostgreSQL connection
if ! psql -d postgres -c "SELECT 1" >/dev/null 2>&1; then
    echo -e "${RED}Error: Cannot connect to PostgreSQL!${NC}"
    echo "Make sure you are running as postgres user with peer authentication enabled."
    exit 1
fi

# ============================================
# CHECK AND CREATE ROLE
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
            # Interactive password prompt
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
# GET DATABASE LIST
# ============================================

echo ""
echo "Fetching database list..."

if [ -n "$DB_LIST_FILE" ]; then
    if [ ! -f "$DB_LIST_FILE" ]; then
        echo -e "${RED}Error: File '$DB_LIST_FILE' not found!${NC}"
        exit 1
    fi
    
    echo "Reading database list from file: $DB_LIST_FILE"
    
    # Get all available databases
    psql -d postgres -tAc \
      "SELECT datname
       FROM pg_database
       WHERE datistemplate = false
       AND datname != 'postgres'" > /tmp/all_available_dbs.txt
    
    > databases_to_change.txt
    found_count=0
    not_found_count=0
    > /tmp/missing_dbs.txt
    
    # Check each database from the list
    while IFS= read -r requested_db || [ -n "$requested_db" ]; do
        # Skip empty lines and comments; strip spaces and invisible characters
        requested_db=$(echo "$requested_db" | sed 's/#.*$//' | tr -d '\r\n' | xargs)
        if [ -z "$requested_db" ]; then continue; fi
        
        # Escape single quotes in the database name for SQL (double them)
        escaped_db=$(printf '%s' "$requested_db" | sed "s/'/''/g")
        
        # Check that the database exists via SQL
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
    # Get all databases (except system ones)
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
# PREVIEW
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
# CONFIRMATION
# ============================================

read -p "Change owner for $need_change database(s)? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Cancelled."
    exit 0
fi

# ============================================
# CHANGE OWNER
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
# RESULTS
# ============================================

echo ""
echo "=== Results ==="
echo -e "${GREEN}Successfully changed: $success${NC}"
if [ $failed -gt 0 ]; then
    echo -e "${RED}Failed: $failed${NC}"
fi

echo ""
echo "Done!"

