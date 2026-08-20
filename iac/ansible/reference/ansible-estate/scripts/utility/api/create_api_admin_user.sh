#!/usr/bin/env bash
# Скрипт для создания администратора в базе данных treasury_api
# Создание пользователя с правами администратора в API сервисе

set -euo pipefail

# Параметры подключения к целевой БД
TARGET_HOST="10.10.16.30"
PG_PORT="5432"
PG_USER="root"
TARGET_PASSWORD=""
DB_NAME="treasury_api"

# ID пользователя из Keycloak
KEYCLOAK_USER_ID=""

# Данные пользователя
USER_EMAIL="admin@example.com"
USER_LAST_NAME="Захаревич"
USER_FIRST_NAME="Павел"
USER_MIDDLE_NAME="Андреевич"

# Используем официальный образ PostgreSQL
PG_IMAGE="postgres:15-alpine"

echo "=== Creating API Administrator User ==="
echo "Database: ${DB_NAME}"
echo "Host: ${TARGET_HOST}:${PG_PORT}"
echo "Keycloak User ID: ${KEYCLOAK_USER_ID}"
echo ""

# Проверка доступности целевого сервера
echo "Checking target server connectivity..."
if ! docker run --rm --network host \
  -e PGPASSWORD="${TARGET_PASSWORD}" \
  "${PG_IMAGE}" \
  psql -h "${TARGET_HOST}" -p "${PG_PORT}" -U "${PG_USER}" -d postgres -c "SELECT 1;" > /dev/null 2>&1; then
    echo "ERROR: Cannot connect to target server ${TARGET_HOST}:${PG_PORT}"
    exit 1
fi
echo "✓ Target server is accessible"

# Проверка существования базы данных
echo "Checking if database '${DB_NAME}' exists..."
if ! docker run --rm --network host \
  -e PGPASSWORD="${TARGET_PASSWORD}" \
  "${PG_IMAGE}" \
  psql -h "${TARGET_HOST}" -p "${PG_PORT}" -U "${PG_USER}" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}';" | grep -q 1; then
    echo "ERROR: Database '${DB_NAME}' does not exist on target server"
    exit 1
fi
echo "✓ Database '${DB_NAME}' exists"

# Проверка существования таблицы
echo "Checking if table 'public.app_user' exists..."
if ! docker run --rm --network host \
  -e PGPASSWORD="${TARGET_PASSWORD}" \
  "${PG_IMAGE}" \
  psql -h "${TARGET_HOST}" -p "${PG_PORT}" -U "${PG_USER}" -d "${DB_NAME}" -tAc "SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='app_user';" | grep -q 1; then
    echo "ERROR: Table 'public.app_user' does not exist"
    exit 1
fi
echo "✓ Table 'public.app_user' exists"

# Проверка, не существует ли уже пользователь с таким ID
echo "Checking if user with ID '${KEYCLOAK_USER_ID}' already exists..."
if docker run --rm --network host \
  -e PGPASSWORD="${TARGET_PASSWORD}" \
  "${PG_IMAGE}" \
  psql -h "${TARGET_HOST}" -p "${PG_PORT}" -U "${PG_USER}" -d "${DB_NAME}" -tAc "SELECT 1 FROM public.app_user WHERE id='${KEYCLOAK_USER_ID}'::uuid;" | grep -q 1; then
    echo "⚠️  WARNING: User with ID '${KEYCLOAK_USER_ID}' already exists!"
    read -p "Do you want to update the existing user? (yes/no): " update_confirm
    if [ "$update_confirm" != "yes" ]; then
        echo "Operation cancelled."
        exit 0
    fi
    echo ""
    echo "Updating existing user..."
    
    docker run --rm --network host \
      -e PGPASSWORD="${TARGET_PASSWORD}" \
      "${PG_IMAGE}" \
      psql -h "${TARGET_HOST}" -p "${PG_PORT}" -U "${PG_USER}" -d "${DB_NAME}" <<EOF
UPDATE public.app_user 
SET 
    is_super_admin = true,
    type = 'REGULAR'::user_type,
    last_name = '${USER_LAST_NAME}',
    first_name = '${USER_FIRST_NAME}',
    middle_name = '${USER_MIDDLE_NAME}'
WHERE id = '${KEYCLOAK_USER_ID}'::uuid;
EOF
    
    if [ $? -eq 0 ]; then
        echo "✓ User updated successfully"
    else
        echo "ERROR: Failed to update user"
        exit 1
    fi
else
    echo "Creating new user..."
    
    echo ""
    echo "⚠️  WARNING: This will create a new administrator user! ⚠️"
    read -p "Are you sure you want to continue? (yes/no): " confirmation
    
    if [ "$confirmation" != "yes" ]; then
        echo "Operation cancelled."
        exit 0
    fi
    
    echo ""
    echo "Executing INSERT statement..."
    
    # Проверяем, не существует ли уже пользователь с таким email
    echo "Checking if user with email '${USER_EMAIL}' already exists..."
    if docker run --rm --network host \
      -e PGPASSWORD="${TARGET_PASSWORD}" \
      "${PG_IMAGE}" \
      psql -h "${TARGET_HOST}" -p "${PG_PORT}" -U "${PG_USER}" -d "${DB_NAME}" \
        -tAc "SELECT 1 FROM public.app_user WHERE email='${USER_EMAIL}';" | grep -q 1; then
        echo "⚠️  WARNING: User with email '${USER_EMAIL}' already exists!"
        read -p "Do you want to update it? (yes/no): " update_email_confirm
        if [ "$update_email_confirm" != "yes" ]; then
            echo "Operation cancelled."
            exit 0
        fi
        # Используем UPDATE вместо INSERT
        docker run --rm --network host \
          -e PGPASSWORD="${TARGET_PASSWORD}" \
          "${PG_IMAGE}" \
          psql -h "${TARGET_HOST}" -p "${PG_PORT}" -U "${PG_USER}" -d "${DB_NAME}" \
            -v ON_ERROR_STOP=1 \
            -c "UPDATE public.app_user SET is_super_admin=true, type='REGULAR'::user_type, last_name='${USER_LAST_NAME}', first_name='${USER_FIRST_NAME}', middle_name='${USER_MIDDLE_NAME}' WHERE email='${USER_EMAIL}';"
        
        if [ $? -eq 0 ]; then
            echo "✓ User updated successfully"
            exit 0
        else
            echo "ERROR: Failed to update user"
            exit 1
        fi
    fi
    
    # Выполняем INSERT с полным выводом
    echo "Executing INSERT with verbose output..."
    docker run --rm --network host \
      -e PGPASSWORD="${TARGET_PASSWORD}" \
      "${PG_IMAGE}" \
      psql -h "${TARGET_HOST}" -p "${PG_PORT}" -U "${PG_USER}" -d "${DB_NAME}" \
        -v ON_ERROR_STOP=1 \
        -c "INSERT INTO public.app_user (id, is_super_admin, type, email, last_name, first_name, middle_name) VALUES ('${KEYCLOAK_USER_ID}'::uuid, true, 'REGULAR'::user_type, '${USER_EMAIL}', '${USER_LAST_NAME}', '${USER_FIRST_NAME}', '${USER_MIDDLE_NAME}');"
    
    RESULT=$?
    
    if [ $RESULT -eq 0 ]; then
        echo "✓ User created successfully"
        
        # Проверяем, что пользователь действительно создан
        echo "Verifying user was created..."
        if docker run --rm --network host \
          -e PGPASSWORD="${TARGET_PASSWORD}" \
          "${PG_IMAGE}" \
          psql -h "${TARGET_HOST}" -p "${PG_PORT}" -U "${PG_USER}" -d "${DB_NAME}" \
            -tAc "SELECT 1 FROM public.app_user WHERE id='${KEYCLOAK_USER_ID}'::uuid;" | grep -q 1; then
            echo "✓ User verified in database"
        else
            echo "⚠️  WARNING: User was not found in database after INSERT!"
            exit 1
        fi
    else
        echo "ERROR: Failed to create user (exit code: $RESULT)"
        exit 1
    fi
fi

echo ""
echo "=== OPERATION COMPLETED SUCCESSFULLY ==="
echo "User with ID '${KEYCLOAK_USER_ID}' has been created/updated in database '${DB_NAME}'"
echo ""
echo "You can verify by running:"
echo "  docker run --rm --network host -e PGPASSWORD='${TARGET_PASSWORD}' ${PG_IMAGE} \\"
echo "    psql -h ${TARGET_HOST} -p ${PG_PORT} -U ${PG_USER} -d ${DB_NAME} -c \"SELECT * FROM public.app_user WHERE id='${KEYCLOAK_USER_ID}'::uuid;\""

