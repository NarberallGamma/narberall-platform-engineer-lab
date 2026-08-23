#!/usr/bin/env bash
# Install logrotate for estate nginx WAF logs (same layout as the WAF host).
# On the WAF host as root: NGINX_ROOT=/docker/nginx ./install-logrotate.sh
# In the repository the script lives relative to the nginx root: scripts/install-logrotate.sh
#
# Modes:
#   install (default) — write /etc/logrotate.d/nginx-proxy
#   create_dirs — create logs/ and per-server_name subdirs from config/*.conf (same as nginx-logs-setup-waf.sh)
#   all — create_dirs first, then install

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NGINX_ROOT="${NGINX_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
LOGS_DIR="${LOGS_DIR:-$NGINX_ROOT/logs}"
TARGET="/etc/logrotate.d/nginx-proxy"
SETUP_WAF="$SCRIPT_DIR/nginx-logs-setup-waf.sh"

usage() {
    echo "Usage: $0 [ install | create_dirs | all ]" >&2
    echo "  install      — $TARGET (default)" >&2
    echo "  create_dirs  — log directories for every host in $NGINX_ROOT/config" >&2
    echo "  all          — create_dirs, then install" >&2
    echo "Env: NGINX_ROOT, LOGS_DIR (for install), NGINX_UID (for create_dirs, see nginx-logs-setup-waf.sh)" >&2
    exit 1
}

install_logrotate() {
    if [[ ! -d "$(dirname "$TARGET")" ]]; then
        echo "ERROR: $TARGET not found (logrotate.d missing?). Run as root." >&2
        exit 1
    fi

    cat > "$TARGET" << EOF
# Nginx WAF logs: root error/access and per-host logs.
# Path: $LOGS_DIR

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
