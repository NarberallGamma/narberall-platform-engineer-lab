#!/bin/bash

# =============================================================================
# Force-close all connections to RDS PostgreSQL
# =============================================================================
# 
# Purpose:
# - Close all active connections to PostgreSQL databases
# - Useful before recreating the RDS instance via Terraform
# - Closes connections of all users (except system ones)
#
# Usage:
# 1. Fill DB_HOST, DB_PASSWORD and PG_IMAGE below
# 2. Run: chmod +x kill_rds_connections.sh && ./kill_rds_connections.sh
#
# Options:
# - A specific database can be set via TARGET_DATABASE
# - If TARGET_DATABASE is empty, connections to all databases are closed
#
# =============================================================================

# RDS connection parameters
DB_HOST="10.10.18.204"  # TODO: set the RDS IP address 
DB_PORT="5432"
DB_USER="root"
DB_PASSWORD=""  # TODO: set the RDS root password

# PostgreSQL version (Docker image)
PG_IMAGE="postgres:15-alpine"  # Can be changed to postgres:14-alpine, postgres:13-alpine, etc.

# Optional: set a specific database whose connections should be closed
# If empty, connections to all databases are closed
TARGET_DATABASE=""  # Example: "treasury_contract" or leave empty for all

# Whether to drop replication slots (for Debezium)
# If true, drops all replication slots before closing connections
KILL_REPLICATION_SLOTS="true"  # true or false

# Check that required parameters are set
if [ -z "$DB_HOST" ] || [ -z "$DB_PASSWORD" ]; then
    echo "❌ Error: DB_HOST and DB_PASSWORD must be set at the top of the script"
    echo "   DB_HOST - RDS PostgreSQL IP address"
    echo "   DB_PASSWORD - root user password"
    exit 1
fi

echo "🔌 Force-closing connections to RDS PostgreSQL..."
echo "   Host: $DB_HOST"
echo "   Port: $DB_PORT"
echo "   User: $DB_USER"
echo "   PostgreSQL Image: $PG_IMAGE"
if [ -n "$TARGET_DATABASE" ]; then
    echo "   Target Database: $TARGET_DATABASE"
else
    echo "   Target Database: ALL"
fi
echo ""

# Close connections
# Always connects to the postgres database, but targets the given DB via SQL
kill_connections() {
    local db_name=$1
    
    echo "📊 Processing database: $db_name"
    
    # List active connections and close them (connect to postgres)
    docker run --rm --network host \
      -e PGPASSWORD="$DB_PASSWORD" \
      "$PG_IMAGE" \
      psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -t -A -c "
        SELECT pg_terminate_backend(pid)
        FROM pg_stat_activity
        WHERE datname = '$db_name'
          AND pid <> pg_backend_pid()
          AND usename NOT IN ('postgres', 'rdsadmin', 'rds_superuser')
          AND state != 'idle';
    " >/dev/null 2>&1
    
    # Also close idle connections (when needed)
    docker run --rm --network host \
      -e PGPASSWORD="$DB_PASSWORD" \
      "$PG_IMAGE" \
      psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -t -A -c "
        SELECT pg_terminate_backend(pid)
        FROM pg_stat_activity
        WHERE datname = '$db_name'
          AND pid <> pg_backend_pid()
          AND usename NOT IN ('postgres', 'rdsadmin', 'rds_superuser')
          AND state = 'idle';
    " >/dev/null 2>&1
    
    # Check remaining connections (connect to postgres)
    local remaining=$(docker run --rm --network host \
      -e PGPASSWORD="$DB_PASSWORD" \
      "$PG_IMAGE" \
      psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -t -A -c "
        SELECT COUNT(*)
        FROM pg_stat_activity
        WHERE datname = '$db_name'
          AND pid <> pg_backend_pid()
          AND usename NOT IN ('postgres', 'rdsadmin', 'rds_superuser');
    " 2>/dev/null | grep -v "^$" | tr -d ' \t\r\n')
    
    if [ "$remaining" = "0" ]; then
        echo "   ✅ All connections to $db_name are closed"
    else
        echo "   ⚠️  Remaining $remaining active connections to $db_name"
    fi
}

# Show current active connections before closing
echo "📋 Current active connections:"
docker run --rm --network host \
  -e PGPASSWORD="$DB_PASSWORD" \
  "$PG_IMAGE" \
  psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -c "
    SELECT 
        datname as database,
        usename as username,
        COUNT(*) as connections,
        string_agg(DISTINCT state, ', ') as states
    FROM pg_stat_activity
    WHERE datname IS NOT NULL
      AND usename NOT IN ('postgres', 'rdsadmin', 'rds_superuser')
    GROUP BY datname, usename
    ORDER BY datname, usename;
" 2>/dev/null

echo ""

# When a specific database is set
if [ -n "$TARGET_DATABASE" ]; then
    kill_connections "$TARGET_DATABASE"
else
    # List all databases (except system ones)
    echo "🔍 Fetching the database list..."
    
    # Check the connection to the postgres database
    if ! docker run --rm --network host \
      -e PGPASSWORD="$DB_PASSWORD" \
      "$PG_IMAGE" \
      psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -c "SELECT 1;" >/dev/null 2>&1; then
        echo "❌ Error: Failed to connect to the postgres database"
        echo "   Check connection parameters: DB_HOST, DB_PORT, DB_USER, DB_PASSWORD"
        exit 1
    fi
    
    # Get the database list
    DATABASES_OUTPUT=$(docker run --rm --network host \
      -e PGPASSWORD="$DB_PASSWORD" \
      "$PG_IMAGE" \
      psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -t -A -c "
        SELECT datname
        FROM pg_database
        WHERE datistemplate = false
          AND datname NOT IN ('postgres', 'template0', 'template1', 'rdsadmin')
        ORDER BY datname;
    " 2>&1)
    
    # Check for errors
    if echo "$DATABASES_OUTPUT" | grep -qi "error\|fatal\|could not connect"; then
        echo "❌ Error fetching the database list:"
        echo "$DATABASES_OUTPUT"
        exit 1
    fi
    
    # Strip noise from the output and build an array
    DATABASES_ARRAY=()
    while IFS= read -r line; do
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [ -n "$line" ] && [[ ! "$line" =~ ^(WARNING|NOTICE|ERROR) ]]; then
            DATABASES_ARRAY+=("$line")
        fi
    done <<< "$DATABASES_OUTPUT"
    
    if [ ${#DATABASES_ARRAY[@]} -eq 0 ]; then
        echo "❌ Failed to get the database list"
        echo "   Command output:"
        echo "$DATABASES_OUTPUT"
        exit 1
    fi
    
    echo "   Databases found: ${#DATABASES_ARRAY[@]}"
    
    # Close connections for each database
    for DB_NAME in "${DATABASES_ARRAY[@]}"; do
        if [ -n "$DB_NAME" ]; then
            kill_connections "$DB_NAME"
        fi
    done
fi

# Drop replication slots (when enabled)
if [ "$KILL_REPLICATION_SLOTS" = "true" ]; then
    echo ""
    echo "🗑️  Dropping replication slots..."
    
    # Always connect to postgres to drop replication slots
    if [ -n "$TARGET_DATABASE" ]; then
        # Drop slots for the specific database
        docker run --rm --network host \
          -e PGPASSWORD="$DB_PASSWORD" \
          "$PG_IMAGE" \
          psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -c "
            SELECT pg_drop_replication_slot(slot_name)
            FROM pg_replication_slots
            WHERE database = '$TARGET_DATABASE';
        " 2>/dev/null
    else
        # Drop all replication slots
        docker run --rm --network host \
          -e PGPASSWORD="$DB_PASSWORD" \
          "$PG_IMAGE" \
          psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -c "
            SELECT pg_drop_replication_slot(slot_name)
            FROM pg_replication_slots
            WHERE database IS NOT NULL
              AND database NOT IN ('postgres', 'template0', 'template1', 'rdsadmin');
        " 2>/dev/null
    fi
    
    echo "   ✅ Replication slots dropped"
fi

echo ""
echo "📋 Check remaining connections:"
docker run --rm --network host \
  -e PGPASSWORD="$DB_PASSWORD" \
  "$PG_IMAGE" \
  psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -c "
    SELECT 
        datname as database,
        usename as username,
        COUNT(*) as connections
    FROM pg_stat_activity
    WHERE datname IS NOT NULL
      AND usename NOT IN ('postgres', 'rdsadmin', 'rds_superuser')
    GROUP BY datname, usename
    ORDER BY datname, usename;
" 2>/dev/null

echo ""
if [ "$KILL_REPLICATION_SLOTS" = "true" ]; then
    echo "📋 Check remaining replication slots:"
    docker run --rm --network host \
      -e PGPASSWORD="$DB_PASSWORD" \
      "$PG_IMAGE" \
      psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -c "
        SELECT 
            slot_name,
            database,
            slot_type,
            active
        FROM pg_replication_slots
        WHERE database IS NOT NULL
          AND database NOT IN ('postgres', 'template0', 'template1', 'rdsadmin');
    " 2>/dev/null
    echo ""
fi

echo "✅ Done! All connections are closed (except system ones)"
if [ "$KILL_REPLICATION_SLOTS" = "true" ]; then
    echo "✅ Replication slots dropped"
fi
echo "💡 The RDS instance can now be safely recreated via Terraform"

