#!/bin/bash

# Connect to PostgreSQL through Docker
# Usage: ./connect_postgres.sh [prod|preprod]
#
# Environment variables (optional):
#   PROD_HOST - PostgreSQL host for PROD (default: postgres.example.com)
#   PROD_USER - user for PROD (default: postgres)
#   PROD_PASSWORD - password for PROD (default: your-password)
#   PROD_DB - database for PROD (default: postgres)
#   PREPROD_HOST - PostgreSQL host for PREPROD (default: postgres.preprod.example.com)
#   PREPROD_USER - user for PREPROD (default: postgres)
#   PREPROD_PASSWORD - password for PREPROD (default: your-password)
#   PREPROD_DB - database for PREPROD (default: postgres)

# PROD configuration
PROD_HOST="${PROD_HOST:-postgres.example.com}"
PROD_USER="${PROD_USER:-postgres}"
PROD_PASSWORD="${PROD_PASSWORD:-your-password}"
PROD_DB="${PROD_DB:-postgres}"

# PREPROD configuration
PREPROD_HOST="${PREPROD_HOST:-postgres.preprod.example.com}"
PREPROD_USER="${PREPROD_USER:-postgres}"
PREPROD_PASSWORD="${PREPROD_PASSWORD:-your-password}"
PREPROD_DB="${PREPROD_DB:-postgres}"

# Connect to PROD
connect_prod() {
    echo "Connecting to PROD PostgreSQL (${PROD_HOST})..."
    docker run -it --rm \
        postgres:15 \
        psql "postgresql://${PROD_USER}:${PROD_PASSWORD}@${PROD_HOST}:5432/${PROD_DB}?sslmode=require"
}

# Connect to PREPROD
connect_preprod() {
    echo "Connecting to PREPROD PostgreSQL (${PREPROD_HOST})..."
    docker run -it --rm \
        postgres:15 \
        psql "postgresql://${PREPROD_USER}:${PREPROD_PASSWORD}@${PREPROD_HOST}:5432/${PREPROD_DB}?sslmode=require"
}

# Resolve environment
ENV="${1:-}"

if [ -z "$ENV" ]; then
    # Interactive choice when the argument is omitted
    echo "Select environment:"
    echo "1) PROD (${PROD_HOST})"
    echo "2) PREPROD (${PREPROD_HOST})"
    read -p "Enter number (1 or 2): " choice
    
    case $choice in
        1)
            connect_prod
            ;;
        2)
            connect_preprod
            ;;
        *)
            echo "Invalid choice. Use 1 or 2."
            exit 1
            ;;
    esac
else
    # Use the command-line argument
    case "$ENV" in
        prod|PROD|production)
            connect_prod
            ;;
        preprod|PREPROD|pre-production)
            connect_preprod
            ;;
        *)
            echo "Invalid argument. Use: prod or preprod"
            echo "Usage: $0 [prod|preprod]"
            exit 1
            ;;
    esac
fi
