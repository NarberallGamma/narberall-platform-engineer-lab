#!/bin/bash

# Скрипт для получения логов из Kubernetes подов
# Использование: 
#   ./kube-logs.sh                    # Интерактивный режим
#   ./kube-logs.sh -n <namespace>     # Указать namespace
#
# Переменные окружения (опционально):
#   K8S_DEFAULT_NAMESPACE - namespace по умолчанию (по умолчанию: default)

set -e

# Цвета для красивого вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Namespace по умолчанию (можно переопределить через переменную окружения)
DEFAULT_NAMESPACE="${K8S_DEFAULT_NAMESPACE:-default}"
NAMESPACE="${DEFAULT_NAMESPACE}"

# Функция для вывода справки
show_help() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Kubernetes Logs Extractor${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Использование:"
    echo "  $0                    # Интерактивный режим"
    echo "  $0 -n <namespace>     # Указать namespace"
    echo "  $0 help               # Показать эту справку"
    echo ""
    echo "Скрипт позволяет:"
    echo "  - Выбрать namespace (по умолчанию: ${DEFAULT_NAMESPACE})"
    echo "  - Выбрать сервис из списка deployments и statefulsets"
    echo "  - Выбрать временной диапазон для логов"
    echo "  - Автоматически определить формат даты из логов"
    echo "  - Сохранить логи в файл .log"
    echo ""
}

# Функция для проверки доступности kubectl
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}Ошибка: kubectl не найден в PATH${NC}"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        echo -e "${RED}Ошибка: Не удалось подключиться к кластеру${NC}"
        exit 1
    fi
}

# Функция для проверки поддержки --until-time в kubectl
check_until_time_support() {
    # Проверяем, поддерживает ли kubectl флаг --until-time
    if kubectl logs --help 2>&1 | grep -q "\-\-until-time"; then
        return 0  # Поддерживается
    else
        return 1  # Не поддерживается
    fi
}

# Функция для проверки существования namespace
check_namespace() {
    local ns="$1"
    if ! kubectl get namespace "$ns" &> /dev/null; then
        echo -e "${RED}Ошибка: Namespace '${ns}' не найден${NC}"
        return 1
    fi
    return 0
}

# Функция для получения списка сервисов (deployments и statefulsets)
get_services() {
    local ns="$1"
    local services=()
    
    # Получаем deployments
    local deployments=$(kubectl -n "$ns" get deployments -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
    for deploy in $deployments; do
        services+=("deployment:$deploy")
    done
    
    # Получаем statefulsets
    local statefulsets=$(kubectl -n "$ns" get statefulsets -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
    for sts in $statefulsets; do
        services+=("statefulset:$sts")
    done
    
    # Выводим массив
    printf '%s\n' "${services[@]}"
}

# Функция для получения подов по сервису
get_pods_for_service() {
    local ns="$1"
    local service_type="$2"
    local service_name="$3"
    
    if [ "$service_type" = "deployment" ]; then
        # Пробуем получить поды через селектор deployment
        local pods=""
        
        # Используем jsonpath для получения всех пар ключ=значение
        local selector_pairs=$(kubectl -n "$ns" get deployment "$service_name" -o jsonpath='{.spec.selector.matchLabels}' 2>/dev/null)
        
        if [ -n "$selector_pairs" ] && [ "$selector_pairs" != "{}" ]; then
            # Преобразуем JSON в формат селектора (key1=value1,key2=value2)
            local selector=$(echo "$selector_pairs" | grep -o '"[^"]*":"[^"]*"' | \
                sed 's/"\([^"]*\)":"\([^"]*\)"/\1=\2/' | tr '\n' ',' | sed 's/,$//')
            
            if [ -n "$selector" ]; then
                pods=$(kubectl -n "$ns" get pods --selector="$selector" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
            fi
        fi
        
        # Если не получилось через селектор, пробуем fallback методы
        if [ -z "$pods" ] || [ -z "$(echo "$pods" | tr -d ' ')" ]; then
            pods=$(kubectl -n "$ns" get pods -l app="$service_name" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || \
                   kubectl -n "$ns" get pods -l app.kubernetes.io/name="$service_name" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || \
                   kubectl -n "$ns" get pods | grep "$service_name" | awk '{print $1}' || echo "")
        fi
        
        echo "$pods"
    elif [ "$service_type" = "statefulset" ]; then
        # Для statefulset поды имеют имя вида: <statefulset-name>-<ordinal>
        local pods=""
        
        # Пробуем получить селектор
        local selector_pairs=$(kubectl -n "$ns" get statefulset "$service_name" -o jsonpath='{.spec.selector.matchLabels}' 2>/dev/null)
        
        if [ -n "$selector_pairs" ] && [ "$selector_pairs" != "{}" ]; then
            local selector=$(echo "$selector_pairs" | grep -o '"[^"]*":"[^"]*"' | \
                sed 's/"\([^"]*\)":"\([^"]*\)"/\1=\2/' | tr '\n' ',' | sed 's/,$//')
            
            if [ -n "$selector" ]; then
                pods=$(kubectl -n "$ns" get pods --selector="$selector" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
            fi
        fi
        
        # Если не получилось через селектор, пробуем fallback методы
        if [ -z "$pods" ] || [ -z "$(echo "$pods" | tr -d ' ')" ]; then
            # Поды statefulset обычно начинаются с имени statefulset
            pods=$(kubectl -n "$ns" get pods | grep "^${service_name}-" | awk '{print $1}' || \
                   kubectl -n "$ns" get pods -l app.kubernetes.io/name="$service_name" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || \
                   kubectl -n "$ns" get pods | grep "$service_name" | awk '{print $1}' || echo "")
        fi
        
        echo "$pods"
    else
        echo ""
    fi
}

# Функция для получения контейнеров в поде (исключая sidecar)
get_application_containers() {
    local ns="$1"
    local pod="$2"
    
    # Получаем все контейнеры
    local containers=$(kubectl -n "$ns" get pod "$pod" -o jsonpath='{.spec.containers[*].name}' 2>/dev/null || echo "")
    
    # Фильтруем sidecar контейнеры
    local app_containers=()
    for container in $containers; do
        # Исключаем известные sidecar контейнеры
        if [[ ! "$container" =~ ^(istio-proxy|sidecar|envoy|linkerd-proxy|vault-agent)$ ]]; then
            app_containers+=("$container")
        fi
    done
    
    # Если не нашли, берем первый контейнер или "application"
    if [ ${#app_containers[@]} -eq 0 ]; then
        # Пробуем найти контейнер с именем "application"
        if echo "$containers" | grep -q "application"; then
            echo "application"
        else
            # Берем первый контейнер
            echo "$containers" | awk '{print $1}'
        fi
    else
        # Если нашли несколько, предпочитаем "application"
        if printf '%s\n' "${app_containers[@]}" | grep -q "^application$"; then
            echo "application"
        else
            printf '%s\n' "${app_containers[@]}" | head -1
        fi
    fi
}

# Функция для определения формата даты из логов
detect_date_format() {
    local ns="$1"
    local pod="$2"
    local container="$3"
    
    # Получаем последние 50 строк логов
    local sample_logs=$(kubectl -n "$ns" logs "$pod" -c "$container" --tail=50 2>/dev/null || echo "")
    
    if [ -z "$sample_logs" ]; then
        echo ""
        return
    fi
    
    # Ищем различные форматы дат в логах
    # RFC3339: 2025-12-18T13:41:05.741+03:00 или 2025-12-18T13:41:05Z
    if echo "$sample_logs" | grep -qE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}'; then
        echo "rfc3339"
        return
    fi
    
    # ISO 8601: 2025-12-18 13:41:05
    if echo "$sample_logs" | grep -qE '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}'; then
        echo "iso8601"
        return
    fi
    
    # Unix timestamp
    if echo "$sample_logs" | grep -qE '^[0-9]{10}\.[0-9]+'; then
        echo "unix"
        return
    fi
    
    echo "unknown"
}

# Функция для определения часового пояса из логов
detect_timezone() {
    local ns="$1"
    local pod="$2"
    local container="$3"
    
    # Получаем последние 50 строк логов (больше, чтобы точно найти дату с часовым поясом)
    local sample_logs=$(kubectl -n "$ns" logs "$pod" -c "$container" --tail=50 2>/dev/null || echo "")
    
    if [ -z "$sample_logs" ]; then
        echo ""
        return
    fi
    
    # Ищем часовой пояс в различных форматах:
    # 1. С миллисекундами: 2025-12-18T13:41:05.741+03:00
    local timezone=$(echo "$sample_logs" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?[+\-][0-9]{2}:[0-9]{2}' | head -1 | grep -oE '[+\-][0-9]{2}:[0-9]{2}$' | head -1)
    
    if [ -n "$timezone" ]; then
        echo "$timezone"
        return
    fi
    
    # 2. Без миллисекунд: 2025-12-18T13:41:05+03:00
    timezone=$(echo "$sample_logs" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[+\-][0-9]{2}:[0-9]{2}' | head -1 | grep -oE '[+\-][0-9]{2}:[0-9]{2}$' | head -1)
    
    if [ -n "$timezone" ]; then
        echo "$timezone"
        return
    fi
    
    # 3. Если не найден, проверяем наличие Z (UTC)
    if echo "$sample_logs" | grep -qE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?Z[^a-zA-Z]'; then
        echo "Z"
        return
    fi
    
    # 4. Если все еще не найден, пробуем найти любую дату и посмотреть на формат
    local first_date=$(echo "$sample_logs" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}' | head -1)
    if [ -n "$first_date" ]; then
        # Проверяем, есть ли после даты что-то (миллисекунды или часовой пояс)
        local date_with_tz=$(echo "$sample_logs" | grep -oE "${first_date}[\.\+\-Z].*" | head -1)
        if [[ "$date_with_tz" =~ [+\-][0-9]{2}:[0-9]{2} ]]; then
            timezone=$(echo "$date_with_tz" | grep -oE '[+\-][0-9]{2}:[0-9]{2}' | head -1)
            if [ -n "$timezone" ]; then
                echo "$timezone"
                return
            fi
        fi
    fi
    
    echo ""
}

# Функция для получения примера даты из логов
get_date_example() {
    local ns="$1"
    local pod="$2"
    local container="$3"
    
    # Получаем последние 10 строк логов
    local sample_logs=$(kubectl -n "$ns" logs "$pod" -c "$container" --tail=10 2>/dev/null || echo "")
    
    if [ -z "$sample_logs" ]; then
        echo ""
        return
    fi
    
    # Ищем первую дату в формате RFC3339 (с часовым поясом или без)
    local date_example=$(echo "$sample_logs" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?([\+\-][0-9]{2}:[0-9]{2}|Z)?' | head -1)
    
    if [ -n "$date_example" ]; then
        echo "$date_example"
        return
    fi
    
    # Если не найден RFC3339, пробуем ISO8601
    date_example=$(echo "$sample_logs" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}' | head -1)
    
    if [ -n "$date_example" ]; then
        echo "$date_example"
        return
    fi
    
    echo ""
}

# Функция для парсинга даты в формате логов
parse_log_date() {
    local date_str="$1"
    local format="$2"
    
    case "$format" in
        "rfc3339")
            # Пробуем разные варианты RFC3339
            if [[ "$date_str" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}) ]]; then
                echo "${BASH_REMATCH[1]}"
            else
                echo "$date_str"
            fi
            ;;
        "iso8601")
            echo "$date_str" | sed 's/ .*//'
            ;;
        *)
            echo "$date_str"
            ;;
    esac
}

# Функция для получения логов
get_logs() {
    local ns="$1"
    local container="$2"
    local time_filter="$3"
    local output_file="$4"
    shift 4
    local pods=("$@")
    
    # Проверяем, что путь к файлу указан
    if [ -z "$output_file" ]; then
        echo -e "${RED}Ошибка: Не указан путь для сохранения файла${NC}" >&2
        return 1
    fi
    
    local temp_file=$(mktemp)
    
    echo -e "${CYAN}Сбор логов...${NC}"
    
    # Определяем часовой пояс из первого пода, если время указано без часового пояса
    local detected_timezone=""
    if [ ${#pods[@]} -gt 0 ] && [ -n "${pods[0]}" ]; then
        local first_pod="${pods[0]}"
        # Проверяем, есть ли в time_filter время без часового пояса
        if [[ "$time_filter" == *"--since-time="* ]] && [[ ! "$time_filter" =~ [\+\-][0-9]{2}:[0-9]{2} ]] && [[ ! "$time_filter" =~ Z[^a-zA-Z] ]] && [[ ! "$time_filter" =~ Z$ ]]; then
            detected_timezone=$(detect_timezone "$ns" "$first_pod" "$container")
            echo "  [DEBUG] Определен часовой пояс из логов: '${detected_timezone}'" >&2
            if [ -z "$detected_timezone" ]; then
                # Если не удалось определить, проверяем, есть ли вообще логи в поде
                local test_logs=$(kubectl -n "$ns" logs "$first_pod" -c "$container" --tail=5 2>/dev/null || echo "")
                if [ -z "$test_logs" ]; then
                    echo "  [DEBUG] Логи в поде пустые, используем UTC по умолчанию" >&2
                    detected_timezone="Z"
                else
                    echo "  [DEBUG] Логи есть, но часовой пояс не определен. Пробуем найти вручную..." >&2
                    # Пробуем найти любую дату в логах
                    local sample_date=$(echo "$test_logs" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}' | head -1)
                    if [ -n "$sample_date" ]; then
                        echo "  [DEBUG] Найдена дата в логах: $sample_date" >&2
                        # Пробуем найти полную строку с датой
                        local full_date_line=$(echo "$test_logs" | grep -m1 "$sample_date")
                        echo "  [DEBUG] Строка с датой: ${full_date_line:0:100}..." >&2
                    fi
                    # Используем UTC как fallback, но предупредим пользователя
                    detected_timezone="Z"
                fi
            fi
        fi
    fi
    
    local pod_count=0
    for pod in "${pods[@]}"; do
        if [ -z "$pod" ]; then
            continue
        fi
        
        echo -e "${BLUE}Обработка пода: ${pod}${NC}"
        
        # Формируем команду kubectl logs
        local log_cmd="kubectl -n $ns logs $pod -c $container --prefix=true"
        
        # Проверяем, нужно ли фильтровать по end_time (если --until-time не поддерживается)
        local end_time=""
        local actual_time_filter="$time_filter"
        
        if [[ "$time_filter" == *"|END_TIME:"* ]]; then
            # Извлекаем end_time и actual_time_filter
            end_time=$(echo "$time_filter" | sed 's/.*|END_TIME://')
            actual_time_filter=$(echo "$time_filter" | sed 's/|END_TIME:.*//')
        fi
        
        # Если время без часового пояса и мы определили часовой пояс, добавляем его
        if [ -n "$detected_timezone" ] && [[ "$actual_time_filter" == *"--since-time="* ]]; then
            # Извлекаем значение времени из --since-time=...
            local time_value=$(echo "$actual_time_filter" | sed 's/.*--since-time=//' | sed 's/|.*//')
            # Проверяем, не имеет ли уже время часового пояса (Z или +/-HH:MM)
            if [[ ! "$time_value" =~ [\+\-][0-9]{2}:[0-9]{2}$ ]] && [[ ! "$time_value" =~ Z$ ]]; then
                # Добавляем часовой пояс к времени
                actual_time_filter=$(echo "$actual_time_filter" | sed "s/--since-time=${time_value}/--since-time=${time_value}${detected_timezone}/")
                echo "  [DEBUG] Добавлен часовой пояс из логов: ${detected_timezone}" >&2
            fi
        fi
        
        # Добавляем фильтр по времени
        if [ -n "$actual_time_filter" ] && [ "$actual_time_filter" != "" ]; then
            log_cmd="$log_cmd $actual_time_filter"
        fi
        
        # Получаем логи и добавляем заголовок
        {
            echo "=== Pod: $pod ==="
            local log_output
            log_output=$(eval "$log_cmd" 2>&1)
            local log_exit_code=$?
            
            # Отладочная информация (временно)
            if [ -n "$end_time" ]; then
                echo "  [DEBUG] Команда: $log_cmd" >&2
                echo "  [DEBUG] Exit code: $log_exit_code" >&2
                echo "  [DEBUG] Размер вывода: ${#log_output} байт" >&2
                if [ ${#log_output} -lt 200 ]; then
                    echo "  [DEBUG] Содержимое: $log_output" >&2
                fi
            fi
            
            if [ $log_exit_code -eq 0 ]; then
                if [ -n "$log_output" ]; then
                    # Если нужно фильтровать по end_time
                    if [ -n "$end_time" ]; then
                        # Автоматически определяем формат даты в логах
                        local date_format=$(detect_date_format "$ns" "$pod" "$container")
                        
                        # Преобразуем end_time в формат для сравнения (убираем Z и часовой пояс, оставляем только дату и время)
                        local end_time_compare=$(echo "$end_time" | sed 's/Z$//' | sed 's/[+-][0-9][0-9]:[0-9][0-9]$//' | sed 's/\.[0-9]*$//')
                        
                        # Создаем временный файл для фильтрованных логов
                        local filtered_output=""
                        local has_data=0
                        
                        # Фильтруем строки логов, где дата меньше или равна end_time
                        while IFS= read -r line; do
                            # Всегда оставляем заголовки и пустые строки
                            if [[ "$line" == "=== Pod:"* ]] || [[ -z "$line" ]]; then
                                filtered_output="${filtered_output}${line}"$'\n'
                                has_data=1
                                continue
                            fi
                            
                            # Извлекаем дату из строки в зависимости от определенного формата
                            local line_date=""
                            local line_date_compare=""
                            
                            case "$date_format" in
                                "rfc3339")
                                    # RFC3339: 2025-12-18T13:41:05.741+03:00 или 2025-12-18T13:41:05Z
                                    line_date=$(echo "$line" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}' | head -1)
                                    if [ -n "$line_date" ]; then
                                        # Убираем миллисекунды и часовой пояс для сравнения
                                        line_date_compare=$(echo "$line_date" | sed 's/\.[0-9]*$//' | sed 's/[+-][0-9][0-9]:[0-9][0-9]$//')
                                    fi
                                    ;;
                                "iso8601")
                                    # ISO 8601: 2025-12-18 13:41:05
                                    line_date=$(echo "$line" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}' | head -1)
                                    if [ -n "$line_date" ]; then
                                        # Преобразуем в формат для сравнения (заменяем пробел на T)
                                        line_date_compare=$(echo "$line_date" | sed 's/ /T/' | sed 's/\.[0-9]*$//')
                                    fi
                                    ;;
                                *)
                                    # Неизвестный формат или формат не определен - пробуем RFC3339
                                    line_date=$(echo "$line" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}' | head -1)
                                    if [ -z "$line_date" ]; then
                                        # Пробуем ISO8601
                                        line_date=$(echo "$line" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}' | head -1)
                                        if [ -n "$line_date" ]; then
                                            line_date_compare=$(echo "$line_date" | sed 's/ /T/' | sed 's/\.[0-9]*$//')
                                        fi
                                    else
                                        line_date_compare=$(echo "$line_date" | sed 's/\.[0-9]*$//' | sed 's/[+-][0-9][0-9]:[0-9][0-9]$//')
                                    fi
                                    ;;
                            esac
                            
                            if [ -n "$line_date_compare" ]; then
                                # Сравниваем даты (строковое сравнение работает для ISO8601)
                                # Используем [[ ]] для сравнения: если line_date <= end_time
                                if [[ "$line_date_compare" < "$end_time_compare" ]] || [[ "$line_date_compare" == "$end_time_compare" ]]; then
                                    filtered_output="${filtered_output}${line}"$'\n'
                                    has_data=1
                                fi
                            else
                                # Если не удалось извлечь дату, оставляем строку
                                # (может быть служебная информация или строка в другом формате)
                                filtered_output="${filtered_output}${line}"$'\n'
                                has_data=1
                            fi
                        done <<< "$log_output"
                        
                        # Выводим отфильтрованные логи
                        if [ $has_data -eq 1 ]; then
                            echo -n "$filtered_output"
                        else
                            # Если после фильтрации ничего не осталось, но были исходные данные
                            # Выводим первые несколько строк для отладки
                            local first_lines=$(echo "$log_output" | head -5)
                            echo "⚠ Предупреждение: Все строки были отфильтрованы по end_time: $end_time_compare"
                            echo "  Первые строки исходных логов для отладки:"
                            echo "$first_lines" | sed 's/^/  /'
                            echo "  (Попробуйте проверить формат даты в логах)"
                        fi
                    else
                        echo "$log_output"
                    fi
                else
                    # Логи пустые - выводим более информативное сообщение
                    if [ -n "$end_time" ]; then
                        echo "Логи пусты или отсутствуют для данного временного диапазона"
                        echo "  Проверьте:"
                        echo "  - Правильность формата времени в --since-time"
                        echo "  - Наличие логов в указанном временном диапазоне"
                        echo "  - Доступность пода и контейнера"
                    else
                        echo "Логи пусты или отсутствуют для данного временного диапазона"
                    fi
                fi
            else
                echo "Ошибка при получении логов: $log_output"
                echo "  Команда: $log_cmd"
            fi
            echo ""
        } >> "$temp_file"
        
        ((pod_count++))
    done
    
    # Проверяем, есть ли данные в временном файле
    if [ ! -f "$temp_file" ]; then
        echo -e "${RED}Ошибка: Временный файл не был создан${NC}"
        return 1
    fi
    
    # Проверяем размер файла для отладки
    local file_size=0
    if [ -f "$temp_file" ]; then
        file_size=$(wc -c < "$temp_file" 2>/dev/null || echo "0")
    fi
    
    # Сохраняем файл в текущую директорию (pwd)
    # Файл всегда сохраняется в директории, откуда запущен скрипт
    if mv "$temp_file" "$output_file" 2>/dev/null; then
        # Получаем полный абсолютный путь к файлу
        local abs_path="$(pwd)/${output_file}"
        
        echo ""
        if [ -s "$output_file" ]; then
            echo -e "${GREEN}✓ Логи успешно сохранены!${NC}"
        else
            echo -e "${YELLOW}⚠ Файл сохранен, но он пустой${NC}"
        fi
        echo -e "${CYAN}Имя файла: ${output_file}${NC}"
        echo -e "${CYAN}Полный путь: ${abs_path}${NC}"
        local final_size=$(wc -c < "$output_file" 2>/dev/null || echo "0")
        echo -e "${CYAN}Размер: ${final_size} байт${NC}"
        echo -e "${CYAN}Обработано подов: ${pod_count}${NC}"
        
        if [ ! -s "$output_file" ]; then
            echo ""
            echo -e "${YELLOW}Возможные причины пустого файла:${NC}"
            echo -e "${YELLOW}  - Указанный временной диапазон не содержит логов${NC}"
            echo -e "${YELLOW}  - Под не содержит логи в указанном контейнере${NC}"
            echo -e "${YELLOW}  - Нет доступа к логам${NC}"
        fi
        echo ""
    else
        echo -e "${RED}Ошибка: Не удалось сохранить файл${NC}" >&2
        rm -f "$temp_file"
        return 1
    fi
}

# Функция для получения списка namespace
get_namespaces() {
    kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | tr ' ' '\n' | sort
}

# Функция для интерактивного выбора namespace
select_namespace() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Выбор Namespace${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Получаем список namespace
    local namespaces=($(get_namespaces))
    
    if [ ${#namespaces[@]} -eq 0 ]; then
        echo -e "${YELLOW}Не удалось получить список namespace${NC}"
        echo ""
        read -p "Введите namespace вручную [${DEFAULT_NAMESPACE}]: " input_ns
        
        if [ -z "$input_ns" ]; then
            input_ns="$DEFAULT_NAMESPACE"
        fi
        
        if ! check_namespace "$input_ns"; then
            return 1
        fi
        
        NAMESPACE="$input_ns"
        echo -e "${GREEN}✓ Выбран namespace: ${NAMESPACE}${NC}"
        echo ""
        return 0
    fi
    
    # Выводим список namespace с номерами
    local index=1
    local default_index=0
    
    for ns in "${namespaces[@]}"; do
        local marker=""
        if [ "$ns" = "$DEFAULT_NAMESPACE" ]; then
            marker="${GREEN}✓${NC} (по умолчанию)"
            default_index=$index
        fi
        echo -e "  ${index}) ${BLUE}${ns}${NC} ${marker}"
        ((index++))
    done
    echo ""
    
    # Запрашиваем выбор
    if [ $default_index -gt 0 ]; then
        read -p "Выберите namespace (1-${#namespaces[@]}) или 'q' для выхода [${default_index}]: " choice
    else
        read -p "Выберите namespace (1-${#namespaces[@]}) или введите имя вручную, 'q' для выхода: " choice
    fi
    
    # Проверка на выход
    if [ "$choice" = "q" ] || [ "$choice" = "Q" ]; then
        echo "Отменено"
        return 1
    fi
    
    # Если пустой ввод и есть default, используем его
    if [ -z "$choice" ] && [ $default_index -gt 0 ]; then
        choice=$default_index
    fi
    
    # Проверяем, является ли выбор числом
    if [[ "$choice" =~ ^[0-9]+$ ]]; then
        # Выбор по номеру
        if [ "$choice" -ge 1 ] && [ "$choice" -le ${#namespaces[@]} ]; then
            NAMESPACE="${namespaces[$((choice-1))]}"
        else
            echo -e "${RED}Неверный номер!${NC}"
            return 1
        fi
    else
        # Ввод вручную
        if [ -z "$choice" ]; then
            choice="$DEFAULT_NAMESPACE"
        fi
        
        # Проверяем, есть ли такой namespace в списке
        local found=0
        for ns in "${namespaces[@]}"; do
            if [ "$ns" = "$choice" ]; then
                found=1
                break
            fi
        done
        
        if [ $found -eq 1 ]; then
            NAMESPACE="$choice"
        else
            # Пробуем использовать введенное значение (может быть новый namespace)
            if check_namespace "$choice"; then
                NAMESPACE="$choice"
            else
                echo -e "${RED}Namespace '${choice}' не найден!${NC}"
                return 1
            fi
        fi
    fi
    
    echo -e "${GREEN}✓ Выбран namespace: ${NAMESPACE}${NC}"
    echo ""
    return 0
}

# Функция для интерактивного выбора сервиса
select_service() {
    local ns="$1"
    
    # Выводим заголовок и список в stderr, чтобы они были видны при использовании $()
    echo "" >&2
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
    echo -e "${CYAN}Выбор сервиса${NC}" >&2
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
    echo "" >&2
    
    local services=($(get_services "$ns"))
    
    if [ ${#services[@]} -eq 0 ]; then
        echo -e "${YELLOW}В namespace '${ns}' не найдено deployments или statefulsets${NC}" >&2
        return 1
    fi
    
    # Выводим список сервисов в stderr
    local index=1
    for service in "${services[@]}"; do
        local service_type=$(echo "$service" | cut -d: -f1)
        local service_name=$(echo "$service" | cut -d: -f2-)
        echo -e "  ${index}) ${BLUE}${service_name}${NC} (${service_type})" >&2
        ((index++))
    done
    echo "" >&2
    
    # Запрашиваем выбор в цикле, пока не получим валидный
    while true; do
        read -p "Выберите сервис (1-${#services[@]}) или 'q' для выхода: " choice
        
        # Проверка на выход
        if [ "$choice" = "q" ] || [ "$choice" = "Q" ]; then
            echo "Отменено" >&2
            return 1
        fi
        
        # Проверка на пустой ввод
        if [ -z "$choice" ]; then
            echo -e "${YELLOW}Пожалуйста, введите номер сервиса${NC}" >&2
            continue
        fi
        
        # Проверяем валидность выбора
        if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
            echo -e "${RED}Неверный выбор! Введите число от 1 до ${#services[@]}${NC}" >&2
            continue
        fi
        
        if [ "$choice" -lt 1 ] || [ "$choice" -gt ${#services[@]} ]; then
            echo -e "${RED}Неверный выбор! Введите число от 1 до ${#services[@]}${NC}" >&2
            continue
        fi
        
        # Валидный выбор - возвращаем результат в stdout
        local selected_service="${services[$((choice-1))]}"
        echo "$selected_service"
        return 0
    done
}

# Функция для выбора временного диапазона
select_time_range() {
    local date_format="$1"
    local ns="$2"
    local pod="$3"
    local container="$4"
    
    # Получаем реальный пример даты из логов
    local date_example=""
    if [ -n "$ns" ] && [ -n "$pod" ] && [ -n "$container" ]; then
        date_example=$(get_date_example "$ns" "$pod" "$container")
    fi
    
    # Если не удалось получить пример, используем стандартный
    if [ -z "$date_example" ]; then
        date_example="2025-12-18T13:41:05+03:00"
    fi
    
    # Выводим заголовок и список в stderr, чтобы они были видны при использовании $()
    echo "" >&2
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
    echo -e "${CYAN}Выбор временного диапазона${NC}" >&2
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
    echo "" >&2
    echo "  1) За последний час" >&2
    echo "  2) За последние 3 часа" >&2
    echo "  3) За последние 6 часов" >&2
    echo "  4) За произвольное количество часов" >&2
    echo "  5) За произвольное количество минут" >&2
    echo "  6) За определенный период времени (начало и конец)" >&2
    echo "  7) Все доступные логи" >&2
    echo "" >&2
    
    read -p "Выберите вариант (1-7): " time_choice
    
    case "$time_choice" in
        1)
            echo "--since=1h"
            ;;
        2)
            echo "--since=3h"
            ;;
        3)
            echo "--since=6h"
            ;;
        4)
            read -p "Введите количество часов: " hours
            if [[ "$hours" =~ ^[0-9]+$ ]]; then
                echo "--since=${hours}h"
            else
                echo -e "${RED}Неверное значение!${NC}" >&2
                return 1
            fi
            ;;
        5)
            read -p "Введите количество минут: " minutes
            if [[ "$minutes" =~ ^[0-9]+$ ]]; then
                echo "--since=${minutes}m"
            else
                echo -e "${RED}Неверное значение!${NC}" >&2
                return 1
            fi
            ;;
        6)
            echo "" >&2
            # Используем реальный пример даты из логов
            local example_with_tz="$date_example"
            local example_without_tz=$(echo "$date_example" | sed 's/[+\-][0-9][0-9]:[0-9][0-9]$//' | sed 's/Z$//' | sed 's/\.[0-9]*$//')
            
            if [ -n "$date_example" ]; then
                echo -e "${YELLOW}Формат даты: RFC3339 (пример из логов: ${example_with_tz})${NC}" >&2
                if [ "$example_with_tz" != "$example_without_tz" ]; then
                    echo -e "${YELLOW}Можно также указать без часового пояса: ${example_without_tz}${NC}" >&2
                fi
            else
                echo -e "${YELLOW}Формат даты: RFC3339 (например: 2025-12-18T13:41:05+03:00 или 2025-12-18T13:41:05Z)${NC}" >&2
                echo -e "${YELLOW}Можно также указать без часового пояса: 2025-12-18T13:41:05${NC}" >&2
            fi
            echo "" >&2
            read -p "Введите время начала: " start_time
            read -p "Введите время конца: " end_time
            
            if [ -z "$start_time" ] || [ -z "$end_time" ]; then
                echo -e "${RED}Оба времени должны быть указаны!${NC}" >&2
                return 1
            fi
            
            # Преобразуем в RFC3339 формат, если нужно
            # Добавляем секунды, если их нет (формат должен быть HH:MM:SS, а не HH:MM)
            if [[ "$start_time" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}$ ]]; then
                # Формат YYYY-MM-DDTHH:MM - добавляем секунды
                start_time="${start_time}:00"
            elif [[ "$start_time" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}[+\-][0-9]{2}:[0-9]{2}$ ]]; then
                # Формат YYYY-MM-DDTHH:MM+HH:MM - добавляем секунды перед часовым поясом
                start_time=$(echo "$start_time" | sed 's/\(T[0-9][0-9]:[0-9][0-9]\)\([+\-]\)/\1:00\2/')
            fi
            
            if [[ "$end_time" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}$ ]]; then
                # Формат YYYY-MM-DDTHH:MM - добавляем секунды
                end_time="${end_time}:00"
            elif [[ "$end_time" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}[+\-][0-9]{2}:[0-9]{2}$ ]]; then
                # Формат YYYY-MM-DDTHH:MM+HH:MM - добавляем секунды перед часовым поясом
                end_time=$(echo "$end_time" | sed 's/\(T[0-9][0-9]:[0-9][0-9]\)\([+\-]\)/\1:00\2/')
            fi
            
            # Если нет часового пояса, НЕ добавляем Z автоматически
            # Часовой пояс будет определен из логов в get_logs()
            # Это позволяет использовать часовой пояс из самих логов, а не принудительно UTC
            
            # Проверяем поддержку --until-time
            if check_until_time_support; then
                echo "--since-time=${start_time} --until-time=${end_time}"
            else
                # Если --until-time не поддерживается, используем только --since-time
                # и сохраняем end_time для последующей фильтрации
                echo -e "${YELLOW}⚠ Ваша версия kubectl не поддерживает --until-time${NC}" >&2
                echo -e "${YELLOW}Логи будут отфильтрованы по дате окончания в самих логах${NC}" >&2
                echo "--since-time=${start_time}|END_TIME:${end_time}"
            fi
            ;;
        7)
            echo ""
            ;;
        *)
            echo -e "${RED}Неверный выбор!${NC}" >&2
            return 1
            ;;
    esac
}


# Основная функция
main() {
    # Парсим аргументы
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            -h|--help|help)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}Неизвестный аргумент: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Проверяем kubectl
    check_kubectl
    
    # Выбираем namespace
    if ! select_namespace; then
        exit 1
    fi
    
    # Проверяем namespace
    if ! check_namespace "$NAMESPACE"; then
        exit 1
    fi
    
    # Выбираем сервис
    local selected_service=$(select_service "$NAMESPACE")
    if [ -z "$selected_service" ]; then
        exit 1
    fi
    
    local service_type=$(echo "$selected_service" | cut -d: -f1)
    local service_name=$(echo "$selected_service" | cut -d: -f2-)
    
    echo -e "${GREEN}✓ Выбран сервис: ${service_name} (${service_type})${NC}"
    
    # Получаем поды для сервиса
    local pods=($(get_pods_for_service "$NAMESPACE" "$service_type" "$service_name"))
    
    if [ ${#pods[@]} -eq 0 ] || [ -z "${pods[0]}" ]; then
        echo -e "${YELLOW}Не найдено подов для сервиса '${service_name}'${NC}"
        exit 1
    fi
    
    echo -e "${CYAN}Найдено подов: ${#pods[@]}${NC}"
    for pod in "${pods[@]}"; do
        echo -e "  - ${pod}"
    done
    
    # Определяем контейнер приложения (берем первый под)
    local first_pod="${pods[0]}"
    local container=$(get_application_containers "$NAMESPACE" "$first_pod")
    
    if [ -z "$container" ]; then
        echo -e "${YELLOW}Не удалось определить контейнер приложения, используется 'application'${NC}"
        container="application"
    fi
    
    echo -e "${GREEN}✓ Используется контейнер: ${container}${NC}"
    
    # Определяем формат даты из логов (для внутреннего использования)
    local date_format=$(detect_date_format "$NAMESPACE" "$first_pod" "$container")
    
    # Выбираем временной диапазон (передаем информацию о поде для получения реального примера даты)
    local time_filter=$(select_time_range "$date_format" "$NAMESPACE" "$first_pod" "$container")
    if [ $? -ne 0 ]; then
        exit 1
    fi
    
    # Генерируем имя файла - всегда сохраняем в текущую директорию (pwd)
    local output_file="${service_name}-logs-$(date +%Y%m%d_%H%M%S).log"
    
    echo ""
    echo -e "${CYAN}Файл будет сохранен в текущей директории: $(pwd)${NC}"
    echo ""
    
    # Получаем логи
    if get_logs "$NAMESPACE" "$container" "$time_filter" "$output_file" "${pods[@]}"; then
        echo -e "${GREEN}Готово!${NC}"
    else
        echo -e "${RED}Произошла ошибка при сохранении логов${NC}"
        exit 1
    fi
}

# Запуск
main "$@"

