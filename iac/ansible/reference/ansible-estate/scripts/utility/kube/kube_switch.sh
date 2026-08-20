#!/bin/bash

# Скрипт для переключения между Kubernetes кластерами
# Использование: 
#   ./kube_switch.sh                    # Интерактивный выбор кластера
#   ./kube_switch.sh <cluster-name>     # Переключение на указанный кластер
#   ./kube_switch.sh list               # Показать список доступных кластеров
#   ./kube_switch.sh current            # Показать текущий активный кластер

set -e

# Цвета для красивого вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Путь к папке с конфигами кластеров
KUBE_CLUSTERS_DIR="${HOME}/.kube/clusters"
KUBE_CONFIG_DIR="${HOME}/.kube"

# Создаем папку для конфигов, если её нет
mkdir -p "$KUBE_CLUSTERS_DIR"

# Функция для вывода справки
show_help() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Kubernetes Cluster Switcher${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Использование:"
    echo "  $0                    # Интерактивный выбор кластера"
    echo "  $0 <cluster-name>     # Переключение на указанный кластер"
    echo "  $0 list               # Показать список доступных кластеров"
    echo "  $0 current            # Показать текущий активный кластер"
    echo "  $0 help               # Показать эту справку"
    echo ""
    echo "Конфиги кластеров должны быть сохранены в: ${KUBE_CLUSTERS_DIR}/<cluster-name>/config"
    echo "Структура: каждая подпапка с именем кластера содержит файл 'config'"
    echo ""
}

# Функция для получения списка доступных кластеров
list_clusters() {
    echo -e "${CYAN}Доступные кластеры:${NC}"
    echo ""
    
    if [ ! -d "$KUBE_CLUSTERS_DIR" ]; then
        echo -e "${YELLOW}Папка с конфигами не найдена: ${KUBE_CLUSTERS_DIR}${NC}"
        echo ""
        echo "Для добавления кластера создайте папку и скопируйте конфиг:"
        echo "  mkdir -p ${KUBE_CLUSTERS_DIR}/<cluster-name>"
        echo "  cp /path/to/config ${KUBE_CLUSTERS_DIR}/<cluster-name>/config"
        echo ""
        return 1
    fi
    
    local clusters=()
    local current_cluster=""
    
    # Определяем текущий активный кластер
    if [ -f "${KUBE_CONFIG_DIR}/config" ]; then
        current_cluster=$(kubectl config current-context 2>/dev/null || echo "")
    fi
    
    # Собираем список кластеров (ищем подпапки с файлом config)
    for cluster_dir in "$KUBE_CLUSTERS_DIR"/*; do
        if [ -d "$cluster_dir" ] && [ -f "$cluster_dir/config" ]; then
            local cluster_name=$(basename "$cluster_dir")
            clusters+=("$cluster_name")
        fi
    done
    
    if [ ${#clusters[@]} -eq 0 ]; then
        echo -e "${YELLOW}Конфиги кластеров не найдены!${NC}"
        echo ""
        echo "Для добавления кластера создайте папку и скопируйте конфиг:"
        echo "  mkdir -p ${KUBE_CLUSTERS_DIR}/<cluster-name>"
        echo "  cp /path/to/config ${KUBE_CLUSTERS_DIR}/<cluster-name>/config"
        echo ""
        return 1
    fi
    
    # Выводим список
    local index=1
    for cluster in "${clusters[@]}"; do
        local marker=""
        if [ -n "$current_cluster" ] && echo "$current_cluster" | grep -q "$cluster"; then
            marker="${GREEN}✓${NC}"
        else
            marker=" "
        fi
        echo -e "  ${marker} ${index}) ${BLUE}${cluster}${NC}"
        ((index++))
    done
    echo ""
    
    return 0
}

# Функция для показа текущего кластера
show_current() {
    if [ ! -f "${KUBE_CONFIG_DIR}/config" ]; then
        echo -e "${YELLOW}Активный конфиг не найден${NC}"
        return 1
    fi
    
    local current_context=$(kubectl config current-context 2>/dev/null || echo "не установлен")
    local current_cluster=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}' 2>/dev/null || echo "не определен")
    
    echo -e "${CYAN}Текущий активный кластер:${NC}"
    echo -e "  Context: ${GREEN}${current_context}${NC}"
    echo -e "  Cluster: ${GREEN}${current_cluster}${NC}"
    echo ""
    
    # Показываем путь к активному конфигу
    if [ -L "${KUBE_CONFIG_DIR}/config" ]; then
        local symlink_target=$(readlink -f "${KUBE_CONFIG_DIR}/config")
        echo -e "  Конфиг: ${symlink_target}"
    else
        echo -e "  Конфиг: ${KUBE_CONFIG_DIR}/config (прямой файл)"
    fi
    echo ""
}

# Функция для переключения на кластер
switch_cluster() {
    local cluster_name="$1"
    local config_file="${KUBE_CLUSTERS_DIR}/${cluster_name}/config"
    
    # Проверяем существование конфига
    if [ ! -f "$config_file" ]; then
        echo -e "${RED}Ошибка: Конфиг для кластера '${cluster_name}' не найден!${NC}"
        echo ""
        echo "Конфиг должен находиться по пути: ${config_file}"
        echo ""
        echo "Доступные кластеры:"
        list_clusters
        return 1
    fi
    
    # Проверяем валидность конфига
    if ! kubectl --kubeconfig="$config_file" cluster-info &>/dev/null; then
        echo -e "${YELLOW}Предупреждение: Не удалось проверить подключение к кластеру${NC}"
        echo "Конфиг будет активирован, но возможно потребуется обновление токенов/сертификатов"
        echo ""
    fi
    
    # Создаем симлинк или копируем конфиг
    if [ -L "${KUBE_CONFIG_DIR}/config" ] || [ ! -f "${KUBE_CONFIG_DIR}/config" ]; then
        # Если это симлинк или файла нет, создаем новый симлинк
        ln -sf "$config_file" "${KUBE_CONFIG_DIR}/config"
    else
        # Если это обычный файл, делаем резервную копию и создаем симлинк
        local backup_file="${KUBE_CONFIG_DIR}/config.backup.$(date +%Y%m%d_%H%M%S)"
        cp "${KUBE_CONFIG_DIR}/config" "$backup_file"
        echo -e "${YELLOW}Создана резервная копия: ${backup_file}${NC}"
        rm "${KUBE_CONFIG_DIR}/config"
        ln -sf "$config_file" "${KUBE_CONFIG_DIR}/config"
    fi
    
    # Проверяем текущий контекст
    local current_context=$(kubectl config current-context 2>/dev/null || echo "")
    
    echo -e "${GREEN}✓ Успешно переключено на кластер: ${cluster_name}${NC}"
    if [ -n "$current_context" ]; then
        echo -e "  Context: ${current_context}"
    fi
    echo ""
    
    # Показываем информацию о кластере
    echo -e "${CYAN}Информация о кластере:${NC}"
    kubectl cluster-info 2>/dev/null || echo -e "${YELLOW}Не удалось получить информацию о кластере${NC}"
    echo ""
}

# Функция для интерактивного выбора кластера
interactive_select() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Выбор Kubernetes кластера${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Получаем список кластеров
    local clusters=()
    local current_cluster=""
    
    if [ -f "${KUBE_CONFIG_DIR}/config" ]; then
        current_cluster=$(kubectl config current-context 2>/dev/null || echo "")
    fi
    
    # Собираем список кластеров (ищем подпапки с файлом config)
    for cluster_dir in "$KUBE_CLUSTERS_DIR"/*; do
        if [ -d "$cluster_dir" ] && [ -f "$cluster_dir/config" ]; then
            local cluster_name=$(basename "$cluster_dir")
            clusters+=("$cluster_name")
        fi
    done
    
    if [ ${#clusters[@]} -eq 0 ]; then
        echo -e "${YELLOW}Конфиги кластеров не найдены!${NC}"
        echo ""
        echo "Для добавления кластера создайте папку и скопируйте конфиг:"
        echo "  mkdir -p ${KUBE_CLUSTERS_DIR}/<cluster-name>"
        echo "  cp /path/to/config ${KUBE_CLUSTERS_DIR}/<cluster-name>/config"
        echo ""
        return 1
    fi
    
    # Выводим список с номерами
    local index=1
    for cluster in "${clusters[@]}"; do
        local marker=""
        if [ -n "$current_cluster" ] && echo "$current_cluster" | grep -q "$cluster"; then
            marker="${GREEN}✓${NC} (текущий)"
        else
            marker=" "
        fi
        echo -e "  ${index}) ${BLUE}${cluster}${NC} ${marker}"
        ((index++))
    done
    echo ""
    
    # Запрашиваем выбор
    read -p "Выберите кластер (1-${#clusters[@]}) или 'q' для выхода: " choice
    
    if [ "$choice" = "q" ] || [ "$choice" = "Q" ]; then
        echo "Отменено"
        return 0
    fi
    
    # Проверяем валидность выбора
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#clusters[@]} ]; then
        echo -e "${RED}Неверный выбор!${NC}"
        return 1
    fi
    
    # Переключаемся на выбранный кластер
    local selected_cluster="${clusters[$((choice-1))]}"
    switch_cluster "$selected_cluster"
}

# Основная логика
main() {
    local command="${1:-}"
    
    case "$command" in
        "list"|"ls")
            list_clusters
            ;;
        "current"|"cur")
            show_current
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        "")
            interactive_select
            ;;
        *)
            switch_cluster "$command"
            ;;
    esac
}

# Запуск
main "$@"

