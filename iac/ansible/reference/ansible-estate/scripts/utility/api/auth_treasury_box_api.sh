#!/bin/bash

# Универсальный скрипт для автоматической OTP авторизации в treasury Box API
# Использование: ./auth_treasury_box_api.sh [ENV] [LOGIN] [COMPANY_ID] [PASSWORD]
#
# Переменные окружения (опционально):
#   AUTH_DOMAIN_PROD - домен auth сервиса для PROD (по умолчанию: auth.example.com)
#   WEB_DOMAIN_PROD - домен web сервиса для PROD (по умолчанию: web.example.com)
#   AUTH_DOMAIN_PREPROD - домен auth сервиса для PREPROD (по умолчанию: auth.preprod.example.com)
#   WEB_DOMAIN_PREPROD - домен web сервиса для PREPROD (по умолчанию: web.preprod.example.com)
#   AUTH_DOMAIN_DEMO - домен auth сервиса для DEMO (по умолчанию: auth.demo.example.com)
#   WEB_DOMAIN_DEMO - домен web сервиса для DEMO (по умолчанию: web.demo.example.com)
#   K8S_NAMESPACE - namespace Kubernetes для PROD (по умолчанию: your-namespace)
#   treasury_BOX_LOGIN - логин/телефон (можно указать через параметр)
#   treasury_BOX_COMPANY_ID - UUID компании (можно указать через параметр)
#   treasury_BOX_PASSWORD - пароль для запроса нового OTP (можно указать через параметр, опционально)
# Примеры:
#   export treasury_BOX_LOGIN=+79991234567
#   export treasury_BOX_COMPANY_ID=company-uuid
#   ./auth_treasury_box_api.sh prod                               # ENV=prod, параметры из переменных окружения
#   ./auth_treasury_box_api.sh prod +79991234567 company-uuid     # Все параметры указаны
# Параметры:
#   - ENV: prod/preprod/demo (если не указан, будет запрошен интерактивно)
#   - LOGIN: можно указать через параметр или переменную окружения treasury_BOX_LOGIN
#   - COMPANY_ID: можно указать через параметр или переменную окружения treasury_BOX_COMPANY_ID
#   - PASSWORD: можно указать через параметр или переменную окружения treasury_BOX_PASSWORD (опционально)

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
    echo -e "${CYAN}                      treasury Box API - Авторизация через OTP${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${BLUE}ОПИСАНИЕ:${NC}"
    echo "  Скрипт для автоматической OTP авторизации в treasury Box API."
    echo "  Получает список OTP кодов, находит самый новый валидный код или запрашивает новый,"
    echo "  затем выполняет авторизацию и возвращает Bearer JWT токен."
    echo ""
    echo -e "${BLUE}СИНТАКСИС:${NC}"
    echo "  ./auth_treasury_box_api.sh [ENV] [LOGIN] [COMPANY_ID] [PASSWORD]"
    echo "  ./auth_treasury_box_api.sh [--help|-h]"
    echo ""
    echo -e "${BLUE}ПАРАМЕТРЫ:${NC}"
    echo -e "  ${GREEN}ENV${NC}           Окружение: prod, preprod или demo"
    echo "                Если не указан, будет запрошен интерактивно"
    echo ""
    echo -e "  ${GREEN}LOGIN${NC}         Телефонный номер для авторизации"
    echo "                Можно указать через параметр или переменную окружения treasury_BOX_LOGIN"
    echo ""
    echo -e "  ${GREEN}COMPANY_ID${NC}    UUID компании"
    echo "                Можно указать через параметр или переменную окружения treasury_BOX_COMPANY_ID"
    echo ""
    echo -e "  ${GREEN}PASSWORD${NC}      Пароль для автоматического запроса нового OTP"
    echo "                Можно указать через параметр или переменную окружения treasury_BOX_PASSWORD"
    echo "                Используется только если все существующие OTP коды использованы (опционально)"
    echo ""
    echo -e "  ${GREEN}--help, -h${NC}    Показать эту справку"
    echo ""
    echo -e "${BLUE}ПРИМЕРЫ ИСПОЛЬЗОВАНИЯ:${NC}"
    echo ""
    echo "  # Интерактивный выбор окружения, все параметры по умолчанию"
    echo -e "  ${YELLOW}./auth_treasury_box_api.sh${NC}"
    echo ""
    echo "  # Указано окружение PROD, параметры из переменных окружения"
    echo -e "  ${YELLOW}export treasury_BOX_LOGIN=+79991234567${NC}"
    echo -e "  ${YELLOW}export treasury_BOX_COMPANY_ID=company-uuid${NC}"
    echo -e "  ${YELLOW}./auth_treasury_box_api.sh prod${NC}"
    echo ""
    echo "  # Указаны окружение и логин"
    echo -e "  ${YELLOW}./auth_treasury_box_api.sh prod +79991234567${NC}"
    echo ""
    echo "  # Все параметры указаны"
    echo -e "  ${YELLOW}./auth_treasury_box_api.sh prod +79991234567 company-uuid password${NC}"
    echo ""
    echo "  # Использование переменных окружения"
    echo -e "  ${YELLOW}export treasury_BOX_LOGIN=+79991234567${NC}"
    echo -e "  ${YELLOW}export treasury_BOX_COMPANY_ID=company-uuid${NC}"
    echo -e "  ${YELLOW}./auth_treasury_box_api.sh prod${NC}"
    echo ""
    echo "  # Показать справку"
    echo -e "  ${YELLOW}./auth_treasury_box_api.sh --help${NC}"
    echo ""
    echo -e "${BLUE}ОКРУЖЕНИЯ:${NC}"
    echo -e "  ${GREEN}prod${NC}     Production окружение"
    echo "          • Использует port-forward для обхода WAF"
    echo "          • Автоматически настраивает kubectl port-forward к подам"
    echo "          • URL: localhost:8081 (auth), localhost:8082 (web)"
    echo ""
    echo -e "  ${GREEN}preprod${NC}  Pre-production окружение"
    echo "          • Прямое подключение через внешний URL"
    echo "          • URL: настраивается через переменные AUTH_DOMAIN_PREPROD и WEB_DOMAIN_PREPROD"
    echo ""
    echo -e "  ${GREEN}demo${NC}     Demo окружение"
    echo "          • Прямое подключение через внешний URL"
    echo "          • URL: настраивается через переменные AUTH_DOMAIN_DEMO и WEB_DOMAIN_DEMO"
    echo ""
    echo -e "${BLUE}ОСОБЕННОСТИ:${NC}"
    echo "  • Автоматический поиск самого нового валидного OTP кода"
    echo "  • Автоматический запрос нового OTP, если все коды использованы"
    echo "  • Для PROD: автоматическая настройка port-forward (обход WAF)"
    echo "  • Красивый вывод с цветами и форматированием"
    echo "  • Автоматическая очистка port-forward процессов при завершении"
    echo ""
    echo -e "${BLUE}ЗАВИСИМОСТИ:${NC}"
    echo "  • curl - для HTTP запросов"
    echo "  • jq - для парсинга JSON (рекомендуется, но не обязательно)"
    echo "  • kubectl - только для PROD окружения с port-forward"
    echo ""
    echo -e "${BLUE}НАСТРОЙКА В СКРИПТЕ:${NC}"
    echo "  Вы можете настроить скрипт прямо в его коде:"
    echo ""
    echo -e "  ${YELLOW}• Port-forward:${NC}"
    echo "    Изменить USE_PORT_FORWARD для любого окружения:"
    echo "    - Строки 156, 163, 169 (prod, preprod, demo)"
    echo ""
    echo -e "  ${YELLOW}• URL домены:${NC}"
    echo "    Изменить домены для окружений:"
    echo "    - Строки 154-155, 161-162, 167-168 (AUTH_DOMAIN, WEB_DOMAIN)"
    echo ""
    echo -e "  ${YELLOW}• URL пути:${NC}"
    echo "    Изменить формирование URL в функции setup_urls():"
    echo "    - Строки 406-413 (OTP_API_URL, AUTH_URL, REQUEST_OTP_URL)"
    echo ""
    echo -e "  ${YELLOW}• Параметры по умолчанию:${NC}"
    echo "    Изменить значения по умолчанию можно в коде скрипта"
    echo ""
    echo -e "${BLUE}ВОЗВРАЩАЕТ:${NC}"
    echo "  Bearer JWT Access Token, который можно использовать для авторизации в API"
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
            AUTH_DOMAIN="${AUTH_DOMAIN_PROD:-auth.example.com}"
            WEB_DOMAIN="${WEB_DOMAIN_PROD:-web.example.com}"
            USE_PORT_FORWARD=true  # Для PROD используем port-forward
            K8S_NAMESPACE="${K8S_NAMESPACE:-your-namespace}"
            ;;
        preprod|PREPROD|pre-production)
            ENV="preprod"
            AUTH_DOMAIN="${AUTH_DOMAIN_PREPROD:-auth.preprod.example.com}"
            WEB_DOMAIN="${WEB_DOMAIN_PREPROD:-web.preprod.example.com}"
            USE_PORT_FORWARD=false
            ;;
        demo|DEMO)
            ENV="demo"
            AUTH_DOMAIN="${AUTH_DOMAIN_DEMO:-auth.demo.example.com}"
            WEB_DOMAIN="${WEB_DOMAIN_DEMO:-web.demo.example.com}"
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

# Переменные для хранения PID процессов port-forward
AUTH_PORT_FORWARD_PID=""
WEB_PORT_FORWARD_PID=""
AUTH_LOCAL_PORT=""
WEB_LOCAL_PORT=""

# Функция очистки port-forward процессов при выходе
cleanup_port_forwards() {
    if [ -n "$AUTH_PORT_FORWARD_PID" ]; then
        kill $AUTH_PORT_FORWARD_PID 2>/dev/null && print_info "Остановлен port-forward для auth сервиса (PID: $AUTH_PORT_FORWARD_PID)"
        AUTH_PORT_FORWARD_PID=""
    fi
    if [ -n "$WEB_PORT_FORWARD_PID" ]; then
        kill $WEB_PORT_FORWARD_PID 2>/dev/null && print_info "Остановлен port-forward для web сервиса (PID: $WEB_PORT_FORWARD_PID)"
        WEB_PORT_FORWARD_PID=""
    fi
}

# Регистрация trap для очистки при выходе
trap cleanup_port_forwards EXIT INT TERM

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
    local port_name="${3:-http}"  # По умолчанию ищем порт с именем http
    
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
setup_prod_port_forwards() {
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
    print_info "Настраиваю два port-forward на разных портах: auth (8081) и web/otp (8082)"
    echo ""
    
    # Ищем auth сервис
    print_info "Ищу treasury-auth сервис в namespace $K8S_NAMESPACE..."
    AUTH_SERVICE=$(find_k8s_service "$K8S_NAMESPACE" "treasury-auth")
    
    if [ -z "$AUTH_SERVICE" ]; then
        print_error "Не найден treasury-auth сервис в namespace $K8S_NAMESPACE"
        print_info "Доступные сервисы:"
        kubectl -n "$K8S_NAMESPACE" get svc | grep -E "NAME|auth" || echo "  (нет сервисов с 'auth' в названии)"
        exit 1
    fi
    
    print_success "Найден сервис: $AUTH_SERVICE"
    
    # Получаем порт сервиса (по умолчанию 8080 для actuator)
    AUTH_SERVICE_PORT=$(get_k8s_service_port "$K8S_NAMESPACE" "$AUTH_SERVICE" "http")
    AUTH_SERVICE_PORT="${AUTH_SERVICE_PORT:-8080}"
    AUTH_LOCAL_PORT="8081"
    
    print_info "Порт сервиса $AUTH_SERVICE: $AUTH_SERVICE_PORT"
    
    # Создаем port-forward для auth
    print_info "Создаю port-forward для $AUTH_SERVICE: localhost:$AUTH_LOCAL_PORT -> $K8S_NAMESPACE/$AUTH_SERVICE:$AUTH_SERVICE_PORT"
    AUTH_PORT_FORWARD_PID=$(setup_port_forward "$K8S_NAMESPACE" "$AUTH_SERVICE" "$AUTH_LOCAL_PORT" "$AUTH_SERVICE_PORT" 2>/dev/null)
    if [ -z "$AUTH_PORT_FORWARD_PID" ]; then
        print_error "Не удалось создать port-forward для $AUTH_SERVICE"
        exit 1
    fi
    # Проверяем, что PID - это число
    if ! [[ "$AUTH_PORT_FORWARD_PID" =~ ^[0-9]+$ ]]; then
        print_error "Получен некорректный PID для port-forward: $AUTH_PORT_FORWARD_PID"
        exit 1
    fi
    print_success "Port-forward для auth создан (PID: $AUTH_PORT_FORWARD_PID)"
    
    # Ищем web/otp сервис
    print_info "Ищу treasury-otp/web сервис в namespace $K8S_NAMESPACE..."
    WEB_SERVICE=$(find_k8s_service "$K8S_NAMESPACE" "treasury-otp")
    
    if [ -z "$WEB_SERVICE" ]; then
        # Пробуем найти web сервис
        WEB_SERVICE=$(find_k8s_service "$K8S_NAMESPACE" "web")
    fi
    
    if [ -z "$WEB_SERVICE" ]; then
        # Если не нашли treasury-otp/web, используем тот же auth сервис
        print_warning "Не найден отдельный treasury-otp/web сервис, используем $AUTH_SERVICE"
        WEB_SERVICE="$AUTH_SERVICE"
        WEB_SERVICE_PORT="$AUTH_SERVICE_PORT"
        WEB_LOCAL_PORT="$AUTH_LOCAL_PORT"
        WEB_PORT_FORWARD_PID=""
    else
        print_success "Найден сервис: $WEB_SERVICE"
        WEB_SERVICE_PORT=$(get_k8s_service_port "$K8S_NAMESPACE" "$WEB_SERVICE" "http")
        WEB_SERVICE_PORT="${WEB_SERVICE_PORT:-8080}"
        WEB_LOCAL_PORT="8082"
        
        # Создаем port-forward для web
        print_info "Создаю port-forward для $WEB_SERVICE: localhost:$WEB_LOCAL_PORT -> $K8S_NAMESPACE/$WEB_SERVICE:$WEB_SERVICE_PORT"
        WEB_PORT_FORWARD_PID=$(setup_port_forward "$K8S_NAMESPACE" "$WEB_SERVICE" "$WEB_LOCAL_PORT" "$WEB_SERVICE_PORT" 2>/dev/null)
        if [ -z "$WEB_PORT_FORWARD_PID" ]; then
            print_warning "Не удалось создать port-forward для $WEB_SERVICE, используем $AUTH_SERVICE"
            WEB_LOCAL_PORT="$AUTH_LOCAL_PORT"
            WEB_PORT_FORWARD_PID=""
        else
            # Проверяем, что PID - это число
            if [[ "$WEB_PORT_FORWARD_PID" =~ ^[0-9]+$ ]]; then
                print_success "Port-forward для web создан (PID: $WEB_PORT_FORWARD_PID)"
            else
                print_warning "Получен некорректный PID для port-forward web, используем $AUTH_SERVICE"
                WEB_LOCAL_PORT="$AUTH_LOCAL_PORT"
                WEB_PORT_FORWARD_PID=""
            fi
        fi
    fi
    
    echo ""
    print_info "Жду 2 секунды для стабилизации port-forward соединений..."
    sleep 2
}

# Выбор окружения (может быть передан как первый параметр)
if [ -n "$1" ] && [[ "$1" =~ ^(prod|preprod|demo|PROD|PREPROD|DEMO|production|pre-production)$ ]]; then
    # ENV передан как первый параметр
    select_environment "$1"
    # Параметры смещены - используем переменные окружения или параметры
    LOGIN="${2:-${treasury_BOX_LOGIN:-}}"
    COMPANY_ID="${3:-${treasury_BOX_COMPANY_ID:-}}"
    PASSWORD="${4:-${treasury_BOX_PASSWORD:-}}"
else
    # ENV не передан, выберем интерактивно, параметры не смещены
    select_environment ""
    LOGIN="${1:-${treasury_BOX_LOGIN:-}}"
    COMPANY_ID="${2:-${treasury_BOX_COMPANY_ID:-}}"
    PASSWORD="${3:-${treasury_BOX_PASSWORD:-}}"
fi

# Проверка обязательных параметров
if [ -z "$LOGIN" ] || [ "$LOGIN" = "YOUR_LOGIN_HERE" ]; then
    print_error "LOGIN не указан. Укажите через параметр или переменную окружения treasury_BOX_LOGIN"
    exit 1
fi

if [ -z "$COMPANY_ID" ] || [ "$COMPANY_ID" = "YOUR_COMPANY_ID_HERE" ]; then
    print_error "COMPANY_ID не указан. Укажите через параметр или переменную окружения treasury_BOX_COMPANY_ID"
    exit 1
fi

# PASSWORD опционален (используется только для автоматического запроса нового OTP)

# Функция настройки URL (вызывается после настройки port-forward для PROD)
setup_urls() {
    if [ "$USE_PORT_FORWARD" = "true" ] && [ -n "$AUTH_LOCAL_PORT" ]; then
        # Для PROD с port-forward используем localhost
        # ВАЖНО: При port-forward мы минуем ingress, поэтому убираем ingress-префиксы из путей
        WEB_PORT="${WEB_LOCAL_PORT:-$AUTH_LOCAL_PORT}"
        AUTH_PORT="$AUTH_LOCAL_PORT"
        
        # Пути без ingress-префиксов (прямо к поду)
        OTP_API_URL="http://localhost:${WEB_PORT}/otp/login/${LOGIN}?page=0&size=20"
        AUTH_URL="http://localhost:${AUTH_PORT}/oauth2/token"
        REQUEST_OTP_URL="http://localhost:${AUTH_PORT}/login/otp"
    else
        # Для других окружений используем обычные URL через ingress
        OTP_API_URL="https://${WEB_DOMAIN}/api/v0/treasury-otp/otp/login/${LOGIN}?page=0&size=20"
        AUTH_URL="https://${AUTH_DOMAIN}/api/v0/treasury-auth-provider/oauth2/token"
        REQUEST_OTP_URL="https://${AUTH_DOMAIN}/api/v0/treasury-auth-provider/login/otp"
    fi
}

# Инициализация URL (будет переопределено после port-forward для PROD)
OTP_API_URL=""
AUTH_URL=""
REQUEST_OTP_URL=""

# Функция для запроса нового OTP кода
request_new_otp() {
    local login="$1"
    local password="$2"
    
    if [ -z "$password" ]; then
        return 1
    fi
    
    print_header "Запрос нового OTP кода"
    print_info "Отправляю запрос на генерацию нового OTP кода..."
    
    REQUEST_RESPONSE=$(curl -s -X POST "$REQUEST_OTP_URL" \
        -H 'Content-Type: application/json' \
        -H 'Accept: application/json' \
        -d "{\"login\":\"$login\",\"password\":\"$password\"}")
    
    if [ -z "$REQUEST_RESPONSE" ]; then
        print_error "Пустой ответ от сервера при запросе OTP"
        return 1
    fi
    
    # Проверка на ошибку
    if echo "$REQUEST_RESPONSE" | grep -q '"error"'; then
        print_error "Ошибка при запросе нового OTP:"
        if [ "$HAS_JQ" = true ]; then
            ERROR_DESC=$(echo "$REQUEST_RESPONSE" | jq -r '.error_description // .error // .message')
            echo -e "  ${RED}Описание:${NC} $ERROR_DESC"
            echo "$REQUEST_RESPONSE" | jq .
        else
            echo "$REQUEST_RESPONSE"
        fi
        return 1
    fi
    
    # Проверка успешности
    if [ "$HAS_JQ" = true ]; then
        # Проверяем, что ответ является объектом (не массивом), и пытаемся извлечь message
        if echo "$REQUEST_RESPONSE" | jq -e 'type == "object"' > /dev/null 2>&1; then
            SUCCESS_MESSAGE=$(echo "$REQUEST_RESPONSE" | jq -r 'if .message then .message else "OK" end' 2>/dev/null)
            if [ -n "$SUCCESS_MESSAGE" ] && [ "$SUCCESS_MESSAGE" != "null" ] && [ "$SUCCESS_MESSAGE" != "OK" ]; then
                print_success "Новый OTP код запрошен: $SUCCESS_MESSAGE"
            else
                print_success "Новый OTP код запрошен успешно"
            fi
        else
            print_success "Новый OTP код запрошен успешно"
        fi
    else
        print_success "Новый OTP код запрошен"
    fi
    
    # Небольшая задержка, чтобы OTP код успел появиться в базе
    print_info "Ожидаю появления кода в системе (3 секунды)..."
    sleep 3
    
    return 0
}

# Проверка наличия jq
if ! command -v jq &> /dev/null; then
    print_warning "jq не установлен. Установите для корректной работы: apt-get install jq"
    HAS_JQ=false
else
    HAS_JQ=true
fi

# Настройка port-forward для PROD (если нужно)
if [ "$USE_PORT_FORWARD" = "true" ]; then
    setup_prod_port_forwards
fi

# Настройка URL после port-forward
setup_urls

# Начало работы
clear
print_header "OTP Авторизация"
echo -e "${BLUE}Окружение:${NC} ${ENV^^}"
if [ "$USE_PORT_FORWARD" = "true" ]; then
    echo -e "${BLUE}Режим:${NC} Port-forward (localhost)"
    echo -e "${BLUE}Логин:${NC} $LOGIN"
    echo -e "${BLUE}Company ID:${NC} $COMPANY_ID"
    echo -e "${BLUE}Пароль:${NC} ******** (будет использован для автоматического запроса нового OTP при необходимости)"
    echo ""
    echo -e "${CYAN}Используемые URL через port-forward:${NC}"
    echo -e "  • Auth: http://localhost:${AUTH_LOCAL_PORT}"
    if [ -n "$WEB_LOCAL_PORT" ] && [ "$WEB_LOCAL_PORT" != "$AUTH_LOCAL_PORT" ]; then
        echo -e "  • Web:  http://localhost:${WEB_LOCAL_PORT}"
    else
        echo -e "  • Web:  http://localhost:${AUTH_LOCAL_PORT} (использует auth сервис)"
    fi
else
    echo -e "${BLUE}Логин:${NC} $LOGIN"
    echo -e "${BLUE}Company ID:${NC} $COMPANY_ID"
    echo -e "${BLUE}Пароль:${NC} ******** (будет использован для автоматического запроса нового OTP при необходимости)"
    echo ""
    echo -e "${CYAN}Используемые URL:${NC}"
    echo -e "  • Auth: https://${AUTH_DOMAIN}"
    echo -e "  • Web:  https://${WEB_DOMAIN}"
fi
echo ""

# Проверка, что URL установлены
if [ -z "$OTP_API_URL" ] || [ -z "$AUTH_URL" ] || [ -z "$REQUEST_OTP_URL" ]; then
    print_error "URL не были настроены. Проверьте конфигурацию."
    exit 1
fi

# Шаг 1: Получение списка OTP кодов
print_header "Шаг 1: Получение списка OTP кодов"
print_info "Запрашиваю список OTP кодов..."

# Отладочная информация перед запросом
print_info "URL для запроса: $OTP_API_URL"

if [ "$USE_PORT_FORWARD" = "true" ]; then
    echo ""
    print_info "Проверяю статус port-forward процессов..."
    
    # Проверяем auth port-forward
    if [ -n "$AUTH_PORT_FORWARD_PID" ] && [[ "$AUTH_PORT_FORWARD_PID" =~ ^[0-9]+$ ]]; then
        if ps -p $AUTH_PORT_FORWARD_PID > /dev/null 2>&1; then
            print_success "Port-forward для auth активен (PID: $AUTH_PORT_FORWARD_PID, порт: $AUTH_LOCAL_PORT)"
        else
            print_error "Port-forward для auth НЕ работает (PID: $AUTH_PORT_FORWARD_PID не найден)"
        fi
    elif [ -n "$AUTH_PORT_FORWARD_PID" ]; then
        print_warning "Port-forward для auth: некорректный PID (должен быть числом, получено: $AUTH_PORT_FORWARD_PID)"
    fi
    
    # Проверяем web port-forward
    if [ -n "$WEB_PORT_FORWARD_PID" ] && [[ "$WEB_PORT_FORWARD_PID" =~ ^[0-9]+$ ]]; then
        if ps -p $WEB_PORT_FORWARD_PID > /dev/null 2>&1; then
            print_success "Port-forward для web активен (PID: $WEB_PORT_FORWARD_PID, порт: $WEB_LOCAL_PORT)"
        else
            print_warning "Port-forward для web НЕ работает (PID: $WEB_PORT_FORWARD_PID не найден)"
        fi
    elif [ -n "$WEB_PORT_FORWARD_PID" ]; then
        print_warning "Port-forward для web: некорректный PID (должен быть числом, получено: $WEB_PORT_FORWARD_PID)"
    fi
    
    # Тест доступности портов
    print_info "Проверяю доступность портов..."
    if command -v nc &> /dev/null || command -v netcat &> /dev/null; then
        if nc -z localhost ${WEB_LOCAL_PORT:-8082} 2>/dev/null; then
            print_success "Порт ${WEB_LOCAL_PORT:-8082} доступен"
        else
            print_error "Порт ${WEB_LOCAL_PORT:-8082} НЕ доступен"
        fi
    fi
    echo ""
fi

print_info "Отправляю запрос..."
OTP_LIST_RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$OTP_API_URL" -H 'accept: */*')

# Извлекаем HTTP код и тело ответа
HTTP_CODE=$(echo "$OTP_LIST_RESPONSE" | tail -n 1)
OTP_LIST_RESPONSE=$(echo "$OTP_LIST_RESPONSE" | sed '$d')

print_info "HTTP статус код: $HTTP_CODE"

if [ -z "$OTP_LIST_RESPONSE" ]; then
    print_error "Пустой ответ от OTP API"
    print_info "HTTP код: $HTTP_CODE"
    print_info "URL: $OTP_API_URL"
    if [ "$USE_PORT_FORWARD" = "true" ]; then
        print_info "Проверьте port-forward процессы:"
        print_info "  ps aux | grep 'port-forward'"
        print_info "  kubectl -n $K8S_NAMESPACE get svc | grep otp"
    fi
    exit 1
fi

# Выводим первые строки ответа для отладки
print_info "=== Начало ответа от API ==="
echo "$OTP_LIST_RESPONSE" | head -5
echo "..."
echo ""

# Проверка на ошибку в ответе
if echo "$OTP_LIST_RESPONSE" | grep -q '"error"'; then
    print_error "Ошибка при получении списка OTP кодов:"
    if [ "$HAS_JQ" = true ]; then
        echo "$OTP_LIST_RESPONSE" | jq .
    else
        echo "$OTP_LIST_RESPONSE"
    fi
    exit 1
fi

print_success "Список OTP кодов получен"

# Шаг 2: Извлечение самого нового валидного OTP кода
print_header "Шаг 2: Определение самого нового валидного OTP кода"

if [ "$HAS_JQ" = true ]; then
    TOTAL_CODES=$(echo "$OTP_LIST_RESPONSE" | jq -r '.totalElements // 0' 2>/dev/null || echo "0")
    print_info "Найдено OTP кодов: $TOTAL_CODES"
    echo ""
    
    # Получаем текущее время в формате ISO 8601
    CURRENT_TIME=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")
    
    # Ищем самый новый НЕ VERIFIED код, который еще не истек
    # Фильтруем: status != "VERIFIED" и expireAt > текущее время
    LATEST_VALID=$(echo "$OTP_LIST_RESPONSE" | jq -r --arg now "$CURRENT_TIME" '
        [.content[] | 
        select(.status != "VERIFIED") |
        select(.expireAt > $now)] |
        sort_by(.expireAt) | reverse | .[0]' 2>/dev/null || echo "null")
    
    if [ "$LATEST_VALID" != "null" ] && [ -n "$LATEST_VALID" ]; then
        LATEST_CODE=$(echo "$LATEST_VALID" | jq -r '.code | split(": ")[1]')
        LATEST_EXPIRE=$(echo "$LATEST_VALID" | jq -r '.expireAt')
        LATEST_STATUS=$(echo "$LATEST_VALID" | jq -r '.status')
        
        print_success "Найден валидный OTP код"
        echo -e "  ${BLUE}Код:${NC} $LATEST_CODE"
        echo -e "  ${BLUE}Истекает:${NC} $LATEST_EXPIRE"
        echo -e "  ${BLUE}Статус:${NC} $LATEST_STATUS"
    else
        # Если не нашли неиспользованный код
        print_warning "Валидных неиспользованных кодов не найдено."
        echo ""
        
        # Показываем все коды для отладки
        print_info "Все доступные OTP коды:"
        echo "$OTP_LIST_RESPONSE" | jq -r '.content[] | "  • Код: \(.code | split(": ")[1]) | Статус: \(.status) | Истекает: \(.expireAt)"' 2>/dev/null || print_warning "Не удалось распарсить список кодов"
        echo ""
        
        # Если пароль предоставлен, пытаемся запросить новый OTP
        if [ -n "$PASSWORD" ]; then
            print_info "Пароль предоставлен. Пытаюсь запросить новый OTP код..."
            echo ""
            
            if request_new_otp "$LOGIN" "$PASSWORD"; then
                # Повторно получаем список OTP кодов
                print_info "Получаю обновленный список OTP кодов..."
                OTP_LIST_RESPONSE=$(curl -s -X GET "$OTP_API_URL" -H 'accept: */*')
                
                # Пытаемся найти новый код
                LATEST_VALID=$(echo "$OTP_LIST_RESPONSE" | jq -r --arg now "$CURRENT_TIME" '
                    [.content[] | 
                    select(.status != "VERIFIED") |
                    select(.expireAt > $now)] |
                    sort_by(.expireAt) | reverse | .[0]'
                )
                
                if [ "$LATEST_VALID" != "null" ] && [ -n "$LATEST_VALID" ]; then
                    LATEST_CODE=$(echo "$LATEST_VALID" | jq -r '.code | split(": ")[1]')
                    LATEST_EXPIRE=$(echo "$LATEST_VALID" | jq -r '.expireAt')
                    LATEST_STATUS=$(echo "$LATEST_VALID" | jq -r '.status')
                    
                    print_success "Найден новый валидный OTP код!"
                    echo -e "  ${BLUE}Код:${NC} $LATEST_CODE"
                    echo -e "  ${BLUE}Истекает:${NC} $LATEST_EXPIRE"
                    echo -e "  ${BLUE}Статус:${NC} $LATEST_STATUS"
                else
                    # Если всё равно не нашли, берем самый новый
                    print_warning "Новый код еще не появился в списке. Использую самый новый по времени..."
                    LATEST_CODE=$(echo "$OTP_LIST_RESPONSE" | jq -r '[.content[]] | sort_by(.expireAt) | reverse | .[0] | .code | split(": ")[1]')
                    LATEST_EXPIRE=$(echo "$OTP_LIST_RESPONSE" | jq -r '[.content[]] | sort_by(.expireAt) | reverse | .[0] | .expireAt')
                    LATEST_STATUS=$(echo "$OTP_LIST_RESPONSE" | jq -r '[.content[]] | sort_by(.expireAt) | reverse | .[0] | .status')
                    
                    if [ "$LATEST_CODE" != "null" ] && [ -n "$LATEST_CODE" ]; then
                        echo -e "  ${BLUE}Код:${NC} $LATEST_CODE"
                        echo -e "  ${BLUE}Истекает:${NC} $LATEST_EXPIRE"
                        echo -e "  ${BLUE}Статус:${NC} $LATEST_STATUS"
                    fi
                fi
            else
                print_error "Не удалось запросить новый OTP код"
                echo ""
                print_info "Попробуйте:"
                echo "  1. Проверить правильность пароля"
                echo "  2. Запросить новый OTP код через UI"
                exit 1
            fi
        else
            # Если пароль не предоставлен, используем самый новый (даже если VERIFIED)
            print_warning "Пароль не предоставлен. Пробую использовать самый новый код по времени..."
            echo ""
            
            LATEST_CODE=$(echo "$OTP_LIST_RESPONSE" | jq -r '[.content[]] | sort_by(.expireAt) | reverse | .[0] | .code | split(": ")[1]')
            LATEST_EXPIRE=$(echo "$OTP_LIST_RESPONSE" | jq -r '[.content[]] | sort_by(.expireAt) | reverse | .[0] | .expireAt')
            LATEST_STATUS=$(echo "$OTP_LIST_RESPONSE" | jq -r '[.content[]] | sort_by(.expireAt) | reverse | .[0] | .status')
            
            if [ "$LATEST_CODE" != "null" ] && [ -n "$LATEST_CODE" ]; then
                print_warning "Использую самый новый код (возможно уже использован):"
                echo -e "  ${BLUE}Код:${NC} $LATEST_CODE"
                echo -e "  ${BLUE}Истекает:${NC} $LATEST_EXPIRE"
                echo -e "  ${YELLOW}Статус:${NC} $LATEST_STATUS"
                echo ""
                print_info "💡 Для автоматического запроса нового OTP укажите пароль третьим параметром:"
                echo "   ./auth_treasury_box_api.sh $LOGIN $COMPANY_ID PASSWORD"
            else
                print_error "Не удалось определить OTP код из ответа"
                echo "$OTP_LIST_RESPONSE" | jq .
                exit 1
            fi
        fi
    fi
else
    # Fallback без jq
    print_warning "Использую упрощенный парсинг (рекомендуется установить jq)"
    LATEST_CODE=$(echo "$OTP_LIST_RESPONSE" | grep -o '"code":"[^"]*"' | tail -1 | sed 's/.*: //; s/"$//')
    
    if [ -z "$LATEST_CODE" ]; then
        print_error "Не удалось извлечь OTP код"
        exit 1
    fi
    
    print_success "OTP код извлечен: $LATEST_CODE"
    print_warning "Без jq невозможно проверить статус кода. Установите jq для точной проверки."
fi

# Шаг 3: Авторизация с OTP кодом
print_header "Шаг 3: Авторизация с OTP кодом"
print_info "Отправляю запрос на получение токена..."

TOKEN_RESPONSE=$(curl -s -X POST "$AUTH_URL" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -H 'Accept: application/json' \
  --data-urlencode "login=$LOGIN" \
  --data-urlencode "otp=$LATEST_CODE" \
  --data-urlencode "companyId=$COMPANY_ID" \
  --data-urlencode "grant_type=otp")

# Проверка ответа
if [ -z "$TOKEN_RESPONSE" ]; then
    print_error "Пустой ответ от сервера авторизации"
    exit 1
fi

# Проверка на ошибку
if echo "$TOKEN_RESPONSE" | grep -q '"error"'; then
    print_error "Ошибка авторизации:"
    if [ "$HAS_JQ" = true ]; then
        ERROR_DESC=$(echo "$TOKEN_RESPONSE" | jq -r '.error_description // .error')
        ERROR_CODE=$(echo "$TOKEN_RESPONSE" | jq -r '.error')
        echo -e "  ${RED}Код ошибки:${NC} $ERROR_CODE"
        echo -e "  ${RED}Описание:${NC} $ERROR_DESC"
        echo ""
        
        # Дополнительная информация об использованном коде
        if [ "$LATEST_STATUS" = "VERIFIED" ]; then
            print_warning "Использованный OTP код имеет статус VERIFIED (уже использован)"
        fi
        
        # Проверка времени истечения
        if [ -n "$LATEST_EXPIRE" ]; then
            CURRENT_TIME_EPOCH=$(date -u +%s)
            EXPIRE_TIME_EPOCH=$(date -u -d "$LATEST_EXPIRE" +%s 2>/dev/null || echo "0")
            if [ "$EXPIRE_TIME_EPOCH" -lt "$CURRENT_TIME_EPOCH" ]; then
                print_warning "Время истечения OTP кода: $LATEST_EXPIRE (возможно истек)"
            fi
        fi
    else
        echo "$TOKEN_RESPONSE"
    fi
    echo ""
    print_warning "Возможные причины:"
    echo "  • OTP код уже использован (статус VERIFIED)"
    echo "  • OTP код истек (время expireAt прошло)"
    echo "  • Неверный логин или companyId"
    echo ""
    print_info "💡 Решение: Запросите новый OTP код через UI/API"
    print_info "   Затем повторите запуск скрипта для получения свежего кода"
    exit 1
fi

# Проверка наличия токена
if ! echo "$TOKEN_RESPONSE" | grep -q '"access_token"'; then
    print_error "В ответе отсутствует access_token"
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

