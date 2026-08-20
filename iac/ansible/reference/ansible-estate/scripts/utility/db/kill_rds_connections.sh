#!/bin/bash

# =============================================================================
# Скрипт принудительного закрытия всех соединений к RDS PostgreSQL
# =============================================================================
# 
# Назначение:
# - Закрытие всех активных соединений к базам данных PostgreSQL
# - Полезно перед пересозданием RDS инстанса через Terraform
# - Закрывает соединения всех пользователей (кроме системных)
#
# Использование:
# 1. Заполнить переменные DB_HOST, DB_PASSWORD и PG_IMAGE ниже
# 2. Запустить: chmod +x kill_rds_connections.sh && ./kill_rds_connections.sh
#
# Опции:
# - Можно указать конкретную базу данных через переменную TARGET_DATABASE
# - Если TARGET_DATABASE не указана, закрываются соединения ко всем базам
#
# =============================================================================

# Параметры подключения к RDS
DB_HOST="10.10.18.204"  # TODO: Указать IP адрес RDS 
DB_PORT="5432"
DB_USER="root"
DB_PASSWORD=""  # TODO: Указать пароль root пользователя RDS

# Версия PostgreSQL (Docker образ)
PG_IMAGE="postgres:15-alpine"  # Можно изменить на postgres:14-alpine, postgres:13-alpine и т.д.

# Опционально: указать конкретную базу данных для закрытия соединений
# Если пусто, закрываются соединения ко всем базам
TARGET_DATABASE=""  # Например: "treasury_contract" или оставить пустым для всех

# Удалять ли replication slots (для Debezium)
# Если true, удаляет все replication slots перед закрытием соединений
KILL_REPLICATION_SLOTS="true"  # true или false

# Проверка заполнения обязательных параметров
if [ -z "$DB_HOST" ] || [ -z "$DB_PASSWORD" ]; then
    echo "❌ Ошибка: Необходимо заполнить DB_HOST и DB_PASSWORD в начале скрипта"
    echo "   DB_HOST - IP адрес RDS PostgreSQL"
    echo "   DB_PASSWORD - пароль root пользователя"
    exit 1
fi

echo "🔌 Принудительное закрытие соединений к RDS PostgreSQL..."
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

# Функция для закрытия соединений
# Всегда подключается к базе postgres, но работает с указанной базой через SQL
kill_connections() {
    local db_name=$1
    
    echo "📊 Обработка базы данных: $db_name"
    
    # Получаем список активных соединений и закрываем их (подключаемся к postgres)
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
    
    # Также закрываем idle соединения (если нужно)
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
    
    # Проверяем оставшиеся соединения (подключаемся к postgres)
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
        echo "   ✅ Все соединения к $db_name закрыты"
    else
        echo "   ⚠️  Осталось $remaining активных соединений к $db_name"
    fi
}

# Показываем текущие активные соединения перед закрытием
echo "📋 Текущие активные соединения:"
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

# Если указана конкретная база данных
if [ -n "$TARGET_DATABASE" ]; then
    kill_connections "$TARGET_DATABASE"
else
    # Получаем список всех баз данных (кроме системных)
    echo "🔍 Получение списка баз данных..."
    
    # Проверяем подключение к базе postgres
    if ! docker run --rm --network host \
      -e PGPASSWORD="$DB_PASSWORD" \
      "$PG_IMAGE" \
      psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -c "SELECT 1;" >/dev/null 2>&1; then
        echo "❌ Ошибка: Не удалось подключиться к базе данных postgres"
        echo "   Проверьте параметры подключения: DB_HOST, DB_PORT, DB_USER, DB_PASSWORD"
        exit 1
    fi
    
    # Получаем список баз данных
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
    
    # Проверяем наличие ошибок
    if echo "$DATABASES_OUTPUT" | grep -qi "error\|fatal\|could not connect"; then
        echo "❌ Ошибка при получении списка баз данных:"
        echo "$DATABASES_OUTPUT"
        exit 1
    fi
    
    # Очищаем вывод от лишних символов и создаем массив
    DATABASES_ARRAY=()
    while IFS= read -r line; do
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [ -n "$line" ] && [[ ! "$line" =~ ^(WARNING|NOTICE|ERROR) ]]; then
            DATABASES_ARRAY+=("$line")
        fi
    done <<< "$DATABASES_OUTPUT"
    
    if [ ${#DATABASES_ARRAY[@]} -eq 0 ]; then
        echo "❌ Не удалось получить список баз данных"
        echo "   Вывод команды:"
        echo "$DATABASES_OUTPUT"
        exit 1
    fi
    
    echo "   Найдено баз данных: ${#DATABASES_ARRAY[@]}"
    
    # Закрываем соединения для каждой базы данных
    for DB_NAME in "${DATABASES_ARRAY[@]}"; do
        if [ -n "$DB_NAME" ]; then
            kill_connections "$DB_NAME"
        fi
    done
fi

# Удаление replication slots (если включено)
if [ "$KILL_REPLICATION_SLOTS" = "true" ]; then
    echo ""
    echo "🗑️  Удаление replication slots..."
    
    # Всегда подключаемся к postgres для удаления replication slots
    if [ -n "$TARGET_DATABASE" ]; then
        # Удаляем slots для конкретной базы
        docker run --rm --network host \
          -e PGPASSWORD="$DB_PASSWORD" \
          "$PG_IMAGE" \
          psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -c "
            SELECT pg_drop_replication_slot(slot_name)
            FROM pg_replication_slots
            WHERE database = '$TARGET_DATABASE';
        " 2>/dev/null
    else
        # Удаляем все replication slots
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
    
    echo "   ✅ Replication slots удалены"
fi

echo ""
echo "📋 Проверка оставшихся соединений:"
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
    echo "📋 Проверка оставшихся replication slots:"
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

echo "✅ Готово! Все соединения закрыты (кроме системных)"
if [ "$KILL_REPLICATION_SLOTS" = "true" ]; then
    echo "✅ Replication slots удалены"
fi
echo "💡 Теперь можно безопасно пересоздавать RDS через Terraform"

