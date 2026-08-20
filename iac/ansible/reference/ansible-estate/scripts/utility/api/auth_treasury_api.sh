#!/bin/bash

# Универсальный скрипт для автоматической авторизации в Treasury API через Keycloak
# Использование: ./auth_treasury_api.sh [ENV] [USERNAME] [PASSWORD] [CLIENT_ID] [CLIENT_SECRET]
#
# Переменные окружения (опционально):
#   KEYCLOAK_DOMAIN_PROD - домен Keycloak для PROD (по умолчанию: keycloak.example.com)
#   KEYCLOAK_DOMAIN_PREPROD - домен Keycloak для PREPROD (по умолчанию: keycloak.preprod.example.com)
#   KEYCLOAK_DOMAIN_DEMO - домен Keycloak для DEMO (по умолчанию: keycloak.demo.example.com)
#   K8S_NAMESPACE - namespace Kubernetes для PROD (по умолчанию: your-namespace)
#   KEYCLOAK_USERNAME - имя пользователя (можно указать через параметр)
#   KEYCLOAK_PASSWORD - пароль пользователя (можно указать через параметр)
#   KEYCLOAK_CLIENT_ID - ID клиента (можно указать через параметр)
#   KEYCLOAK_CLIENT_SECRET - секрет клиента (можно указать через параметр)
# Примеры:
#   export KEYCLOAK_USERNAME=username
#   export KEYCLOAK_PASSWORD=password
#   ./auth_treasury_api.sh prod                               # ENV=prod, параметры из переменных окружения
#   ./auth_treasury_api.sh prod username password client_id client_secret  # Все параметры указаны
# Параметры:
#   - ENV: prod/preprod/demo (если не указан, будет запрошен интерактивно)
#   - USERNAME: можно указать через параметр или переменную окружения KEYCLOAK_USERNAME
#   - PASSWORD: можно указать через параметр или переменную окружения KEYCLOAK_PASSWORD
#   - CLIENT_ID: можно указать через параметр или переменную окружения KEYCLOAK_CLIENT_ID
#   - CLIENT_SECRET: можно указать через параметр или переменную окружения KEYCLOAK_CLIENT_SECRET

set -e  # Выход при ошибке

# Цвета для красивого вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Функция вывода справки
show_help() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}                    Treasury API - Авторизация через Keycloak${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${BLUE}ОПИСАНИЕ:${NC}"
    echo "  Скрипт для автоматической авторизации в Treasury API через Keycloak."
    echo "  Получает Bearer JWT токен из Keycloak realm 'treasure' для дальнейшей работы с API."
    echo ""
    echo -e "${BLUE}СИНТАКСИС:${NC}"
    echo "  ./auth_treasury_api.sh [ENV] [USERNAME] [PASSWORD] [CLIENT_ID] [CLIENT_SECRET]"
    echo "  ./auth_treasury_api.sh [--help|-h]"
    echo ""
    echo -e "${BLUE}ПАРАМЕТРЫ:${NC}"
    echo -e "  ${GREEN}ENV${NC}            Окружение: prod, preprod или demo"
    echo "                 Если не указан, будет запрошен интерактивно"
    echo ""
    echo -e "  ${GREEN}USERNAME${NC}       Имя пользователя для авторизации в Keycloak"
    echo "                 Можно указать через параметр или переменную окружения KEYCLOAK_USERNAME"
    echo ""
    echo -e "  ${GREEN}PASSWORD${NC}       Пароль пользователя"
    echo "                 Можно указать через параметр или переменную окружения KEYCLOAK_PASSWORD"
    echo ""
    echo -e "  ${GREEN}CLIENT_ID${NC}      Идентификатор клиента в Keycloak"
    echo "                 Можно указать через параметр или переменную окружения KEYCLOAK_CLIENT_ID"
    echo ""
    echo -e "  ${GREEN}CLIENT_SECRET${NC}  Секрет клиента в Keycloak"
    echo "                 Можно указать через параметр или переменную окружения KEYCLOAK_CLIENT_SECRET"
    echo ""
    echo -e "  ${GREEN}--help, -h${NC}     Показать эту справку"
    echo ""
    echo -e "${BLUE}ПРИМЕРЫ ИСПОЛЬЗОВАНИЯ:${NC}"
    echo ""
    echo "  # Интерактивный выбор окружения, все параметры по умолчанию"
    echo -e "  ${YELLOW}./auth_treasury_api.sh${NC}"
    echo ""
    echo "  # Указано окружение PROD, параметры из переменных окружения"
    echo -e "  ${YELLOW}export KEYCLOAK_USERNAME=username${NC}"
    echo -e "  ${YELLOW}export KEYCLOAK_PASSWORD=password${NC}"
    echo -e "  ${YELLOW}./auth_treasury_api.sh prod${NC}"
    echo ""
    echo "  # Указаны окружение, username и password"
    echo -e "  ${YELLOW}./auth_treasury_api.sh prod username password${NC}"
    echo ""
    echo "  # Все параметры указаны"
    echo -e "  ${YELLOW}./auth_treasury_api.sh prod username password client_id client_secret${NC}"
    echo ""
    echo "  # Использование переменных окружения"
    echo -e "  ${YELLOW}export KEYCLOAK_USERNAME=username${NC}"
    echo -e "  ${YELLOW}export KEYCLOAK_PASSWORD=password${NC}"
    echo -e "  ${YELLOW}./auth_treasury_api.sh prod${NC}"
    echo ""
    echo "  # Показать справку"
    echo -e "  ${YELLOW}./auth_treasury_api.sh --help${NC}"
    echo ""
    echo -e "${BLUE}ОКРУЖЕНИЯ:${NC}"
    echo -e "  ${GREEN}prod${NC}     Production окружение"
    echo "          • Использует port-forward для обхода WAF"
    echo "          • Автоматически настраивает kubectl port-forward к keycloak-http сервису"
    echo "          • URL: localhost:8081"
    echo ""
    echo -e "  ${GREEN}preprod${NC}  Pre-production окружение"
    echo "          • Прямое подключение через внешний URL"
    echo "          • URL: настраивается через переменную KEYCLOAK_DOMAIN_PREPROD"
    echo ""
    echo -e "  ${GREEN}demo${NC}     Demo окружение"
    echo "          • Прямое подключение через внешний URL"
    echo "          • URL: настраивается через переменную KEYCLOAK_DOMAIN_DEMO"
    echo ""
    echo -e "${BLUE}ОСОБЕННОСТИ:${NC}"
    echo "  • Простая авторизация через Keycloak (один запрос)"
    echo "  • Для PROD: автоматическая настройка port-forward (обход WAF)"
    echo "  • Красивый вывод с цветами и форматированием"
    echo "  • Автоматическая очистка port-forward процесса при завершении"
    echo ""
    echo -e "${BLUE}ЗАВИСИМОСТИ:${NC}"
    echo "  • curl - для HTTP запросов"
    echo "  • jq - для парсинга JSON (рекомендуется, но не обязательно)"
    echo "  • kubectl - только для PROD окружения с port-forward"
    echo ""
    echo -e "${BLUE}KEYCLOAK:${NC}"
    echo "  • Realm: treasure"
    echo "  • Endpoint: /realms/treasure/protocol/openid-connect/token"
    echo "  • Grant type: password"
    echo ""
    echo -e "${BLUE}НАСТРОЙКА В СКРИПТЕ:${NC}"
    echo "  Вы можете настроить скрипт прямо в его коде:"
    echo ""
    echo -e "  ${YELLOW}• Port-forward:${NC}"
    echo "    Изменить USE_PORT_FORWARD для любого окружения:"
    echo "    - Строки 160, 166, 171 (prod, preprod, demo)"
    echo ""
    echo -e "  ${YELLOW}• URL домены:${NC}"
    echo "    Изменить KEYCLOAK_DOMAIN для окружений:"
    echo "    - Строки 159, 165, 170 (prod, preprod, demo)"
    echo ""
    echo -e "  ${YELLOW}• URL пути:${NC}"
    echo "    Изменить формирование TOKEN_URL в функции setup_urls():"
    echo "    - Строки 346, 349 (для port-forward и обычного подключения)"
    echo ""
    echo -e "  ${YELLOW}• Параметры по умолчанию:${NC}"
    echo "    Изменить значения по умолчанию можно в коде скрипта"
    echo ""
    echo -e "${BLUE}ВОЗВРАЩАЕТ:${NC}"
    echo "  Bearer JWT Access Token, который можно использовать для авторизации в Treasury API"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Проверка параметров help
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    show_help
    exit 0
fi

# Функция для выбора окружения
select_environment() {
    local env_arg="$1"
    
    if [ -n "$env_arg" ]; then
        ENV=$(echo "$env_arg" | tr '[:upper:]' '[:lower:]')
    else
        # Интерактивный выбор
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${CYAN}Выбор окружения${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo "  1) PROD    (production)"
        echo "  2) PREPROD (pre-production)"
        echo "  3) DEMO    (demo)"
        echo ""
        read -p "Выберите окружение (1-3) [по умолчанию: 1]: " choice
        
        case "${choice:-1}" in
            1)
                ENV="prod"
                ;;
            2)
                ENV="preprod"
                ;;
            3)
                ENV="demo"
                ;;
            *)
                echo -e "${YELLOW}Неверный выбор, используется PROD${NC}"
                ENV="prod"
                ;;
        esac
    fi
    
    # Валидация окружения
    case "$ENV" in
        prod|PROD|production)
            ENV="prod"
            KEYCLOAK_DOMAIN="${KEYCLOAK_DOMAIN_PROD:-keycloak.example.com}"
            USE_PORT_FORWARD=true  # Для PROD используем port-forward
            K8S_NAMESPACE="${K8S_NAMESPACE:-your-namespace}"
            ;;
        preprod|PREPROD|pre-production)
            ENV="preprod"
            KEYCLOAK_DOMAIN="${KEYCLOAK_DOMAIN_PREPROD:-keycloak.preprod.example.com}"
            USE_PORT_FORWARD=false
            ;;
        demo|DEMO)
            ENV="demo"
            KEYCLOAK_DOMAIN="${KEYCLOAK_DOMAIN_DEMO:-keycloak.demo.example.com}"
            USE_PORT_FORWARD=false
            ;;
        *)
            echo -e "${RED}Ошибка: Неверное окружение '$ENV'. Используйте: prod, preprod или demo${NC}"
            exit 1
            ;;
    esac
}

# Функция для красивого вывода заголовков
print_header() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Функция для вывода информации
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Функция для вывода успеха
print_success() {
    echo -e "${GREEN}✅${NC} $1"
}

# Функция для вывода ошибки
print_error() {
    echo -e "${RED}❌${NC} $1"
}

# Функция для вывода предупреждения
print_warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

# Переменные для хранения PID процесса port-forward
KEYCLOAK_PORT_FORWARD_PID=""
KEYCLOAK_LOCAL_PORT=""

# Функция очистки port-forward процесса при выходе
cleanup_port_forward() {
    if [ -n "$KEYCLOAK_PORT_FORWARD_PID" ] && [[ "$KEYCLOAK_PORT_FORWARD_PID" =~ ^[0-9]+$ ]]; then
        kill $KEYCLOAK_PORT_FORWARD_PID 2>/dev/null && print_info "Остановлен port-forward для keycloak (PID: $KEYCLOAK_PORT_FORWARD_PID)"
        KEYCLOAK_PORT_FORWARD_PID=""
    fi
}

# Регистрация trap для очистки при выходе
trap cleanup_port_forward EXIT INT TERM

# Функция поиска сервиса в Kubernetes
find_k8s_service() {
    local namespace="$1"
    local service_pattern="$2"
    
    kubectl -n "$namespace" get svc 2>/dev/null | grep "$service_pattern" | head -1 | awk '{print $1}'
}

# Функция получения порта сервиса из Kubernetes
get_k8s_service_port() {
    local namespace="$1"
    local service_name="$2"
    local port_name="${3:-http}"
    
    # Пытаемся получить порт по имени
    local port=$(kubectl -n "$namespace" get svc "$service_name" -o jsonpath="{.spec.ports[?(@.name==\"$port_name\")].port}" 2>/dev/null)
    
    # Если не найден по имени, берем первый порт
    if [ -z "$port" ]; then
        port=$(kubectl -n "$namespace" get svc "$service_name" -o jsonpath="{.spec.ports[0].port}" 2>/dev/null)
    fi
    
    echo "$port"
}

# Функция создания port-forward для сервиса
# Возвращает PID процесса или пустую строку при ошибке
setup_port_forward() {
    local namespace="$1"
    local service_name="$2"
    local local_port="$3"
    local service_port="$4"
    
    if [ -z "$service_name" ]; then
        return 1
    fi
    
    # Запускаем port-forward в фоне
    kubectl -n "$namespace" port-forward "svc/$service_name" "$local_port:$service_port" > /dev/null 2>&1 &
    local pid=$!
    
    # Ждем немного, чтобы проверить, что процесс запустился
    sleep 1
    if ps -p $pid > /dev/null 2>&1; then
        echo "$pid"
        return 0
    else
        return 1
    fi
}

# Функция настройки port-forward для PROD окружения
setup_prod_port_forward() {
    if [ "$USE_PORT_FORWARD" != "true" ]; then
        return 0
    fi
    
    # Проверяем наличие kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl не найден. Установите kubectl для использования port-forward в PROD окружении."
        exit 1
    fi
    
    # Проверяем доступность кластера
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Не удается подключиться к Kubernetes кластеру. Проверьте контекст kubectl."
        exit 1
    fi
    
    print_header "Настройка port-forward для PROD окружения"
    print_info "Настраиваю port-forward для keycloak на порт 8081"
    echo ""
    
    # Ищем keycloak-http сервис (как в примере)
    print_info "Ищу keycloak-http сервис в namespace $K8S_NAMESPACE..."
    KEYCLOAK_SERVICE=$(find_k8s_service "$K8S_NAMESPACE" "keycloak-http")
    
    if [ -z "$KEYCLOAK_SERVICE" ]; then
        # Пробуем найти любой keycloak сервис
        KEYCLOAK_SERVICE=$(find_k8s_service "$K8S_NAMESPACE" "keycloak")
    fi
    
    if [ -z "$KEYCLOAK_SERVICE" ]; then
        print_error "Не найден keycloak-http/keycloak сервис в namespace $K8S_NAMESPACE"
        print_info "Доступные сервисы:"
        kubectl -n "$K8S_NAMESPACE" get svc | grep -E "NAME|keycloak" || echo "  (нет сервисов с 'keycloak' в названии)"
        exit 1
    fi
    
    print_success "Найден сервис: $KEYCLOAK_SERVICE"
    
    # Получаем порт сервиса (по умолчанию 80 для http)
    KEYCLOAK_SERVICE_PORT=$(get_k8s_service_port "$K8S_NAMESPACE" "$KEYCLOAK_SERVICE" "http")
    KEYCLOAK_SERVICE_PORT="${KEYCLOAK_SERVICE_PORT:-80}"
    KEYCLOAK_LOCAL_PORT="8081"
    
    print_info "Порт сервиса $KEYCLOAK_SERVICE: $KEYCLOAK_SERVICE_PORT"
    
    # Создаем port-forward для keycloak
    print_info "Создаю port-forward для $KEYCLOAK_SERVICE: localhost:$KEYCLOAK_LOCAL_PORT -> $K8S_NAMESPACE/$KEYCLOAK_SERVICE:$KEYCLOAK_SERVICE_PORT"
    KEYCLOAK_PORT_FORWARD_PID=$(setup_port_forward "$K8S_NAMESPACE" "$KEYCLOAK_SERVICE" "$KEYCLOAK_LOCAL_PORT" "$KEYCLOAK_SERVICE_PORT" 2>/dev/null)
    if [ -z "$KEYCLOAK_PORT_FORWARD_PID" ]; then
        print_error "Не удалось создать port-forward для $KEYCLOAK_SERVICE"
        exit 1
    fi
    # Проверяем, что PID - это число
    if ! [[ "$KEYCLOAK_PORT_FORWARD_PID" =~ ^[0-9]+$ ]]; then
        print_error "Получен некорректный PID для port-forward: $KEYCLOAK_PORT_FORWARD_PID"
        exit 1
    fi
    print_success "Port-forward для keycloak создан (PID: $KEYCLOAK_PORT_FORWARD_PID)"
    
    echo ""
    print_info "Жду 2 секунды для стабилизации port-forward соединения..."
    sleep 2
}

# Функция настройки URL (вызывается после настройки port-forward для PROD)
setup_urls() {
    if [ "$USE_PORT_FORWARD" = "true" ] && [ -n "$KEYCLOAK_LOCAL_PORT" ]; then
        # Для PROD с port-forward используем localhost
        # ВАЖНО: При port-forward мы минуем ingress, поэтому используем прямой путь
        TOKEN_URL="http://localhost:${KEYCLOAK_LOCAL_PORT}/realms/treasure/protocol/openid-connect/token"
    else
        # Для других окружений используем обычный URL через ingress
        TOKEN_URL="https://${KEYCLOAK_DOMAIN}/realms/treasure/protocol/openid-connect/token"
    fi
}

# Проверка наличия jq
if ! command -v jq &> /dev/null; then
    print_warning "jq не установлен. Установите для корректной работы: apt-get install jq"
    HAS_JQ=false
else
    HAS_JQ=true
fi

# Выбор окружения (может быть передан как первый параметр)
if [ -n "$1" ] && [[ "$1" =~ ^(prod|preprod|demo|PROD|PREPROD|DEMO|production|pre-production)$ ]]; then
    # ENV передан как первый параметр
    select_environment "$1"
    # Параметры смещены - используем переменные окружения или параметры
    USERNAME="${2:-${KEYCLOAK_USERNAME:-}}"
    PASSWORD="${3:-${KEYCLOAK_PASSWORD:-}}"
    CLIENT_ID="${4:-${KEYCLOAK_CLIENT_ID:-}}"
    CLIENT_SECRET="${5:-${KEYCLOAK_CLIENT_SECRET:-}}"
else
    # ENV не передан, выберем интерактивно, параметры не смещены
    select_environment ""
    USERNAME="${1:-${KEYCLOAK_USERNAME:-}}"
    PASSWORD="${2:-${KEYCLOAK_PASSWORD:-}}"
    CLIENT_ID="${3:-${KEYCLOAK_CLIENT_ID:-}}"
    CLIENT_SECRET="${4:-${KEYCLOAK_CLIENT_SECRET:-}}"
fi

# Проверка обязательных параметров
if [ -z "$USERNAME" ] || [ "$USERNAME" = "YOUR_USERNAME_HERE" ]; then
    print_error "USERNAME не указан. Укажите через параметр или переменную окружения KEYCLOAK_USERNAME"
    exit 1
fi

if [ -z "$PASSWORD" ] || [ "$PASSWORD" = "YOUR_PASSWORD_HERE" ]; then
    print_error "PASSWORD не указан. Укажите через параметр или переменную окружения KEYCLOAK_PASSWORD"
    exit 1
fi

if [ -z "$CLIENT_ID" ] || [ "$CLIENT_ID" = "YOUR_CLIENT_ID_HERE" ]; then
    print_error "CLIENT_ID не указан. Укажите через параметр или переменную окружения KEYCLOAK_CLIENT_ID"
    exit 1
fi

if [ -z "$CLIENT_SECRET" ] || [ "$CLIENT_SECRET" = "YOUR_CLIENT_SECRET_HERE" ]; then
    print_error "CLIENT_SECRET не указан. Укажите через параметр или переменную окружения KEYCLOAK_CLIENT_SECRET"
    exit 1
fi

# Настройка port-forward для PROD (если нужно)
if [ "$USE_PORT_FORWARD" = "true" ]; then
    setup_prod_port_forward
fi

# Настройка URL после port-forward
setup_urls

# Начало работы
clear
print_header "Treasury API Авторизация через Keycloak"
echo -e "${BLUE}Окружение:${NC} ${ENV^^}"
if [ "$USE_PORT_FORWARD" = "true" ]; then
    echo -e "${BLUE}Режим:${NC} Port-forward (localhost)"
    echo -e "${BLUE}Username:${NC} $USERNAME"
    echo -e "${BLUE}Client ID:${NC} $CLIENT_ID"
    echo ""
    echo -e "${CYAN}Используемый URL через port-forward:${NC}"
    echo -e "  • Keycloak: http://localhost:${KEYCLOAK_LOCAL_PORT}"
else
    echo -e "${BLUE}Username:${NC} $USERNAME"
    echo -e "${BLUE}Client ID:${NC} $CLIENT_ID"
    echo ""
    echo -e "${CYAN}Используемый URL:${NC}"
    echo -e "  • Keycloak: https://${KEYCLOAK_DOMAIN}"
fi
echo ""

# Проверка, что URL установлен
if [ -z "$TOKEN_URL" ]; then
    print_error "URL не был настроен. Проверьте конфигурацию."
    exit 1
fi

# Отладочная информация перед запросом
print_info "URL для запроса токена: $TOKEN_URL"

if [ "$USE_PORT_FORWARD" = "true" ]; then
    echo ""
    print_info "Проверяю статус port-forward процесса..."
    
    # Проверяем keycloak port-forward
    if [ -n "$KEYCLOAK_PORT_FORWARD_PID" ] && [[ "$KEYCLOAK_PORT_FORWARD_PID" =~ ^[0-9]+$ ]]; then
        if ps -p $KEYCLOAK_PORT_FORWARD_PID > /dev/null 2>&1; then
            print_success "Port-forward для keycloak активен (PID: $KEYCLOAK_PORT_FORWARD_PID, порт: $KEYCLOAK_LOCAL_PORT)"
        else
            print_error "Port-forward для keycloak НЕ работает (PID: $KEYCLOAK_PORT_FORWARD_PID не найден)"
        fi
    elif [ -n "$KEYCLOAK_PORT_FORWARD_PID" ]; then
        print_warning "Port-forward для keycloak: некорректный PID (должен быть числом, получено: $KEYCLOAK_PORT_FORWARD_PID)"
    fi
    
    # Тест доступности порта
    print_info "Проверяю доступность порта..."
    if command -v nc &> /dev/null || command -v netcat &> /dev/null; then
        if nc -z localhost ${KEYCLOAK_LOCAL_PORT:-8081} 2>/dev/null; then
            print_success "Порт ${KEYCLOAK_LOCAL_PORT:-8081} доступен"
        else
            print_error "Порт ${KEYCLOAK_LOCAL_PORT:-8081} НЕ доступен"
        fi
    fi
    echo ""
fi

# Шаг 1: Получение токена из Keycloak
print_header "Получение токена из Keycloak"
print_info "Отправляю запрос на получение токена..."

TOKEN_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$TOKEN_URL" \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    --data-urlencode "client_id=$CLIENT_ID" \
    --data-urlencode "client_secret=$CLIENT_SECRET" \
    --data-urlencode "grant_type=password" \
    --data-urlencode "username=$USERNAME" \
    --data-urlencode "password=$PASSWORD")

# Извлекаем HTTP код и тело ответа
HTTP_CODE=$(echo "$TOKEN_RESPONSE" | tail -n 1)
TOKEN_RESPONSE=$(echo "$TOKEN_RESPONSE" | sed '$d')

print_info "HTTP статус код: $HTTP_CODE"

if [ -z "$TOKEN_RESPONSE" ]; then
    print_error "Пустой ответ от Keycloak"
    print_info "HTTP код: $HTTP_CODE"
    print_info "URL: $TOKEN_URL"
    if [ "$USE_PORT_FORWARD" = "true" ]; then
        print_info "Проверьте port-forward процесс:"
        print_info "  ps aux | grep 'port-forward'"
        print_info "  kubectl -n $K8S_NAMESPACE get svc | grep keycloak"
    fi
    exit 1
fi

# Проверка на ошибку
if echo "$TOKEN_RESPONSE" | grep -q '"error"'; then
    print_error "Ошибка при получении токена:"
    if [ "$HAS_JQ" = true ]; then
        ERROR_DESC=$(echo "$TOKEN_RESPONSE" | jq -r '.error_description // .error')
        ERROR_CODE=$(echo "$TOKEN_RESPONSE" | jq -r '.error')
        echo -e "  ${RED}Код ошибки:${NC} $ERROR_CODE"
        echo -e "  ${RED}Описание:${NC} $ERROR_DESC"
        echo ""
        echo "Полный ответ:"
        echo "$TOKEN_RESPONSE" | jq .
    else
        echo "$TOKEN_RESPONSE"
    fi
    echo ""
    print_warning "Возможные причины:"
    echo "  • Неверный username или password"
    echo "  • Неверный client_id или client_secret"
    echo "  • Пользователь не имеет доступа к realm 'treasure'"
    exit 1
fi

# Проверка наличия токена
if ! echo "$TOKEN_RESPONSE" | grep -q '"access_token"'; then
    print_error "В ответе отсутствует access_token"
    print_info "Полный ответ:"
    if [ "$HAS_JQ" = true ]; then
        echo "$TOKEN_RESPONSE" | jq .
    else
        echo "$TOKEN_RESPONSE"
    fi
    exit 1
fi

# Извлечение токена
if [ "$HAS_JQ" = true ]; then
    ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')
    TOKEN_TYPE=$(echo "$TOKEN_RESPONSE" | jq -r '.token_type // "Bearer"')
    EXPIRES_IN=$(echo "$TOKEN_RESPONSE" | jq -r '.expires_in // "N/A"')
    REFRESH_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.refresh_token // ""')
else
    ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
    TOKEN_TYPE="Bearer"
    EXPIRES_IN="N/A"
fi

print_success "Авторизация успешна!"

# Финальный вывод токена
print_header "Результат авторизации"

if [ "$HAS_JQ" = true ]; then
    echo -e "${BLUE}Тип токена:${NC} $TOKEN_TYPE"
    if [ "$EXPIRES_IN" != "N/A" ] && [ "$EXPIRES_IN" != "null" ]; then
        echo -e "${BLUE}Истекает через:${NC} $EXPIRES_IN секунд"
    fi
    echo ""
fi

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Bearer JWT Access Token:${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${CYAN}$ACCESS_TOKEN${NC}"
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Дополнительная информация
if [ "$HAS_JQ" = true ] && [ -n "$REFRESH_TOKEN" ] && [ "$REFRESH_TOKEN" != "null" ]; then
    echo -e "${BLUE}Refresh Token:${NC}"
    echo -e "${CYAN}$REFRESH_TOKEN${NC}"
    echo ""
fi

# Пример использования токена
echo -e "${BLUE}Пример использования токена в curl:${NC}"
echo -e "${YELLOW}curl -H \"Authorization: Bearer $ACCESS_TOKEN\" ...${NC}"
echo ""

print_success "Готово! Токен скопирован выше."

