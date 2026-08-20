#!/bin/bash

# Скрипт для подключения к PostgreSQL через Docker
# Использование: ./connect_postgres.sh [prod|preprod]
#
# Переменные окружения (опционально):
#   PROD_HOST - хост PostgreSQL для PROD (по умолчанию: postgres.example.com)
#   PROD_USER - пользователь для PROD (по умолчанию: postgres)
#   PROD_PASSWORD - пароль для PROD (по умолчанию: your-password)
#   PROD_DB - база данных для PROD (по умолчанию: postgres)
#   PREPROD_HOST - хост PostgreSQL для PREPROD (по умолчанию: postgres.preprod.example.com)
#   PREPROD_USER - пользователь для PREPROD (по умолчанию: postgres)
#   PREPROD_PASSWORD - пароль для PREPROD (по умолчанию: your-password)
#   PREPROD_DB - база данных для PREPROD (по умолчанию: postgres)

# Конфигурация PROD
PROD_HOST="${PROD_HOST:-postgres.example.com}"
PROD_USER="${PROD_USER:-postgres}"
PROD_PASSWORD="${PROD_PASSWORD:-your-password}"
PROD_DB="${PROD_DB:-postgres}"

# Конфигурация PREPROD
PREPROD_HOST="${PREPROD_HOST:-postgres.preprod.example.com}"
PREPROD_USER="${PREPROD_USER:-postgres}"
PREPROD_PASSWORD="${PREPROD_PASSWORD:-your-password}"
PREPROD_DB="${PREPROD_DB:-postgres}"

# Функция для подключения к PROD
connect_prod() {
    echo "Подключение к PROD PostgreSQL (${PROD_HOST})..."
    docker run -it --rm \
        postgres:15 \
        psql "postgresql://${PROD_USER}:${PROD_PASSWORD}@${PROD_HOST}:5432/${PROD_DB}?sslmode=require"
}

# Функция для подключения к PREPROD
connect_preprod() {
    echo "Подключение к PREPROD PostgreSQL (${PREPROD_HOST})..."
    docker run -it --rm \
        postgres:15 \
        psql "postgresql://${PREPROD_USER}:${PREPROD_PASSWORD}@${PREPROD_HOST}:5432/${PREPROD_DB}?sslmode=require"
}

# Определение окружения
ENV="${1:-}"

if [ -z "$ENV" ]; then
    # Интерактивный выбор, если параметр не указан
    echo "Выберите окружение:"
    echo "1) PROD (${PROD_HOST})"
    echo "2) PREPROD (${PREPROD_HOST})"
    read -p "Введите номер (1 или 2): " choice
    
    case $choice in
        1)
            connect_prod
            ;;
        2)
            connect_preprod
            ;;
        *)
            echo "Неверный выбор. Используйте 1 или 2."
            exit 1
            ;;
    esac
else
    # Использование параметра командной строки
    case "$ENV" in
        prod|PROD|production)
            connect_prod
            ;;
        preprod|PREPROD|pre-production)
            connect_preprod
            ;;
        *)
            echo "Неверный параметр. Используйте: prod или preprod"
            echo "Использование: $0 [prod|preprod]"
            exit 1
            ;;
    esac
fi

