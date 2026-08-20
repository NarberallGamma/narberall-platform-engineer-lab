#!/usr/bin/env bash
# WAF estate: каталоги логов по server_name + миграция compose со старого маунта ./logs:/var/log/nginx/static.
# Формат записи access — wallarm (см. nginx.conf). Новые vhost в репозитории уже содержат блок директив после server {.
# Запуск из корня nginx на сервере: ./scripts/nginx-logs-setup-waf.sh all
# Или: NGINX_ROOT=/docker/nginx ./scripts/nginx-logs-setup-waf.sh create_dirs

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NGINX_ROOT="${NGINX_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
CONFIG_DIR="$NGINX_ROOT/config"
LOGS_DIR="$NGINX_ROOT/logs"
COMPOSE_FILE="$NGINX_ROOT/docker-compose.yml"

if [[ ! -d "$CONFIG_DIR" ]]; then
    echo "ERROR: config dir not found NGINX_ROOT=$NGINX_ROOT" >&2
    exit 1
fi

fix_compose_volume() {
    echo "[fix_compose_volume] $COMPOSE_FILE"
    if [[ ! -f "$COMPOSE_FILE" ]]; then
        echo "  Compose file not found, skip."
        return 0
    fi
    if grep -q '\./logs:/var/log/nginx/static' "$COMPOSE_FILE" 2>/dev/null; then
        cp -a "$COMPOSE_FILE" "$COMPOSE_FILE.bak.$(date +%Y%m%d%H%M%S)"
        sed -i 's|\./logs:/var/log/nginx/static|./logs:/var/log/nginx|g' "$COMPOSE_FILE"
        echo "  Replaced volume: ./logs -> /var/log/nginx (backup created)."
    else
        echo "  No legacy static mount; nothing to change."
    fi
}

create_dirs() {
    echo "[create_dirs] LOGS_DIR=$LOGS_DIR"
    mkdir -p "$LOGS_DIR"
    # Файлы общего лога (не access.log/error.log — entrypoint образа часто делает на них symlinks на /dev/stdin/out).
    for agg in access-aggregate.log error-aggregate.log; do
        p="$LOGS_DIR/$agg"
        if [[ -L "$p" ]] || [[ ! -e "$p" ]]; then
            rm -f "$p"
            : > "$p"
        fi
    done
    while read -r h; do
        h="${h%$'\r'}"
        [[ -z "$h" ]] && continue
        mkdir -p "$LOGS_DIR/$h"
    done < <(grep -rhE '^[[:space:]]*server_name[[:space:]]+' --include='*.conf' --exclude='wallarm.conf' "$CONFIG_DIR" 2>/dev/null | sed -n 's/^[[:space:]]*server_name[[:space:]]*\([^;]*\).*/\1/p' | tr ' \t' '\n' | sed 's/;//g' | tr -d '\r' | grep -v '^$' | sort -u)
    mkdir -p "$LOGS_DIR/default"
    # В каждом $LOGS_DIR/<server_name>/ nginx пишет access/error и при наличии в vhost — wallarm-security.log.
    # Образ WAF обычно www-data (uid 33); при необходимости задать NGINX_UID из контейнера.
    NGINX_UID="${NGINX_UID:-33}"
    chown -R "${NGINX_UID}:${NGINX_UID}" "$LOGS_DIR" 2>/dev/null || true
    chmod -R 755 "$LOGS_DIR" 2>/dev/null || true
    echo "  Created per-host dirs under $LOGS_DIR (chown ${NGINX_UID}:${NGINX_UID})"
}

run_all() {
    fix_compose_volume
    create_dirs
    echo "Done. Next: nginx -t (в контейнере), docker compose up -d; затем scripts/install-logrotate.sh от root."
}

case "${1:-}" in
    fix_compose_volume) fix_compose_volume ;;
    create_dirs)        create_dirs ;;
    all)                run_all ;;
    *)
        echo "Usage: $0 { fix_compose_volume | create_dirs | all }"
        exit 1
        ;;
esac
