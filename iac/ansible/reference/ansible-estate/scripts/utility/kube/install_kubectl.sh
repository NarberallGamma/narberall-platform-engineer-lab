#!/bin/bash

# Скрипт для установки последней версии kubectl на Linux
# Использование: ./install_kubectl.sh

set -e

# Цвета для красивого вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}Установка kubectl (последняя версия)${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Проверка, установлен ли уже kubectl
if command -v kubectl &> /dev/null; then
    CURRENT_VERSION=$(kubectl version --client --short 2>/dev/null | cut -d' ' -f3 || echo "неизвестна")
    echo -e "${YELLOW}kubectl уже установлен: ${CURRENT_VERSION}${NC}"
    echo ""
    read -p "Продолжить установку последней версии? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Установка отменена"
        exit 0
    fi
fi

# Определение архитектуры
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        KUBECTL_ARCH="amd64"
        ;;
    aarch64|arm64)
        KUBECTL_ARCH="arm64"
        ;;
    *)
        echo -e "${RED}Неподдерживаемая архитектура: $ARCH${NC}"
        exit 1
        ;;
esac

# Определение ОС
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

echo -e "${BLUE}Архитектура: ${KUBECTL_ARCH}${NC}"
echo -e "${BLUE}ОС: ${OS}${NC}"
echo ""

# Получение последней версии kubectl
echo -e "${CYAN}Получение последней версии kubectl...${NC}"
LATEST_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)

if [ -z "$LATEST_VERSION" ]; then
    echo -e "${RED}Ошибка: Не удалось получить версию kubectl${NC}"
    exit 1
fi

echo -e "${GREEN}Последняя версия: ${LATEST_VERSION}${NC}"
echo ""

# Создание временной директории
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

# Скачивание kubectl
DOWNLOAD_URL="https://dl.k8s.io/release/${LATEST_VERSION}/bin/${OS}/${KUBECTL_ARCH}/kubectl"
echo -e "${CYAN}Скачивание kubectl из: ${DOWNLOAD_URL}${NC}"

if ! curl -L -o "$TMP_DIR/kubectl" "$DOWNLOAD_URL"; then
    echo -e "${RED}Ошибка: Не удалось скачать kubectl${NC}"
    exit 1
fi

# Делаем файл исполняемым
chmod +x "$TMP_DIR/kubectl"

# Проверка целостности (опционально, требует установки sha256sum)
if command -v sha256sum &> /dev/null; then
    echo -e "${CYAN}Проверка целостности...${NC}"
    SHA256_URL="https://dl.k8s.io/${LATEST_VERSION}/bin/${OS}/${KUBECTL_ARCH}/kubectl.sha256"
    
    if curl -L -o "$TMP_DIR/kubectl.sha256" "$SHA256_URL"; then
        cd "$TMP_DIR"
        
        # Файл sha256 содержит только хеш, нужно проверить вручную
        EXPECTED_HASH=$(cat kubectl.sha256 | tr -d '[:space:]')
        ACTUAL_HASH=$(sha256sum kubectl | cut -d' ' -f1)
        
        if [ "$EXPECTED_HASH" = "$ACTUAL_HASH" ]; then
            echo -e "${GREEN}✓ Проверка целостности пройдена${NC}"
        else
            echo -e "${YELLOW}⚠ Предупреждение: Проверка целостности не пройдена${NC}"
            echo -e "${YELLOW}  Ожидаемый хеш: ${EXPECTED_HASH}${NC}"
            echo -e "${YELLOW}  Фактический хеш: ${ACTUAL_HASH}${NC}"
            read -p "Продолжить установку? (y/N): " -n 1 -r
            echo ""
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "Установка отменена"
                exit 0
            fi
        fi
        cd - > /dev/null
    else
        echo -e "${YELLOW}⚠ Не удалось скачать файл проверки целостности, пропускаем проверку${NC}"
    fi
fi

# Установка kubectl
echo ""
echo -e "${CYAN}Установка kubectl...${NC}"

# Определение директории для установки
INSTALL_DIR="/usr/local/bin"
if [ ! -w "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}Требуются права sudo для установки в ${INSTALL_DIR}${NC}"
    sudo install -o root -g root -m 0755 "$TMP_DIR/kubectl" "$INSTALL_DIR/kubectl"
else
    install -m 0755 "$TMP_DIR/kubectl" "$INSTALL_DIR/kubectl"
fi

# Проверка установки
if command -v kubectl &> /dev/null; then
    INSTALLED_VERSION=$(kubectl version --client --short 2>/dev/null | cut -d' ' -f3 || echo "неизвестна")
    echo ""
    echo -e "${GREEN}✓ kubectl успешно установлен!${NC}"
    echo -e "${GREEN}Версия: ${INSTALLED_VERSION}${NC}"
    echo ""
    
    # Показываем информацию о kubectl
    echo -e "${CYAN}Информация о kubectl:${NC}"
    kubectl version --client
    echo ""
    
    echo -e "${CYAN}Следующие шаги:${NC}"
    echo "  1. Настройте конфиги кластеров: ~/.kube/clusters/"
    echo "  2. Используйте скрипт для переключения: ./scripts/utility/kube/kube_switch.sh"
    echo ""
else
    echo -e "${RED}Ошибка: kubectl не найден после установки${NC}"
    exit 1
fi

