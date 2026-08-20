#!/usr/bin/env bash
# Установка logrotate для логов nginx WAF estate (как на proxy01mosvkc).
# Запуск на хосте WAF от root: NGINX_ROOT=/docker/nginx ./install-logrotate.sh
# В репозитории скрипт лежит относительно корня nginx: scripts/install-logrotate.sh
#
# Режимы:
#   install (по умолчанию) — записать /etc/logrotate.d/nginx-proxy
#   create_dirs — создать logs/ и подкаталоги по server_name из config/*.conf (как nginx-logs-setup-waf.sh)
#   all — сначала create_dirs, затем install

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NGINX_ROOT="${NGINX_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
LOGS_DIR="${LOGS_DIR:-$NGINX_ROOT/logs}"
TARGET="/etc/logrotate.d/nginx-proxy"
SETUP_WAF="$SCRIPT_DIR/nginx-logs-setup-waf.sh"

usage() {
    echo "Usage: $0 [ install | create_dirs | all ]" >&2
    echo "  install      — $TARGET (по умолчанию)" >&2
    echo "  create_dirs  — каталоги логов под все host из $NGINX_ROOT/config" >&2
    echo "  all          — create_dirs, затем install" >&2
    echo "Env: NGINX_ROOT, LOGS_DIR (для install), NGINX_UID (для create_dirs, см. nginx-logs-setup-waf.sh)" >&2
    exit 1
}

install_logrotate() {
    if [[ ! -d "$(dirname "$TARGET")" ]]; then
        echo "ERROR: $TARGET not found (logrotate.d missing?). Run as root." >&2
        exit 1
    fi

    cat > "$TARGET" << EOF
# Nginx WAF logs: корневые error/access и по хостам.
# Путь: $LOGS_DIR

$LOGS_DIR/*.log
$LOGS_DIR/*/*.log
{
    su root root
    daily
    rotate 7
    maxage 7
    dateext
    dateformat -%Y%m%d
    missingok
    compress
    compresscmd /bin/gzip
    compressoptions "-1"
    copytruncate
}
EOF

    echo "Installed: $TARGET (path: $LOGS_DIR)"
    echo "Check:     logrotate -d $TARGET"
}

create_host_log_dirs() {
    if [[ ! -f "$SETUP_WAF" ]]; then
        echo "ERROR: $SETUP_WAF not found." >&2
        exit 1
    fi
    if [[ ! -x "$SETUP_WAF" ]]; then
        chmod +x "$SETUP_WAF" 2>/dev/null || true
    fi
    echo "[create_host_log_dirs] NGINX_ROOT=$NGINX_ROOT (nginx-logs-setup-waf.sh create_dirs)"
    NGINX_ROOT="$NGINX_ROOT" "$SETUP_WAF" create_dirs
}

cmd="${1:-install}"
case "$cmd" in
    install|'')
        install_logrotate
        ;;
    create_dirs)
        create_host_log_dirs
        ;;
    all)
        create_host_log_dirs
        install_logrotate
        ;;
    -h|--help|help)
        usage
        ;;
    *)
        usage
        ;;
esac

exit 0
