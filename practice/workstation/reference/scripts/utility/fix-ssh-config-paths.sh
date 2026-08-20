#!/usr/bin/env bash
# SSH config: добавление фрагментов, синхронизация Windows -> WSL, исправление путей к ключам.
#
# Windows config (источник правды для новых хостов):
#   /mnt/c/Users/<win_user>/.ssh/config
# WSL config (пути IdentityFile в Linux-формате):
#   ~/.ssh/config
#
# Использование:
#   ./fix-ssh-config-paths.sh fix-paths [FILE]           # Windows -> Linux пути в FILE (по умолчанию ~/.ssh/config)
#   ./fix-ssh-config-paths.sh add-fragment FRAGMENT       # добавить блоки в Windows config (без дубликатов Host)
#   ./fix-ssh-config-paths.sh sync-wsl                      # скопировать Windows config в WSL и fix-paths
#   ./fix-ssh-config-paths.sh apply-fragment FRAGMENT     # add-fragment + sync-wsl
#   ./fix-ssh-config-paths.sh add-host ALIAS IP [OPTIONS]  # один Host-блок в Windows config
#   ./fix-ssh-config-paths.sh set-user HOST USER [HOST USER ...]  # сменить User у существующих Host
#   ./fix-ssh-config-paths.sh remove-host HOST [HOST ...]   # удалить Host-блоки из Windows config
#   ./fix-ssh-config-paths.sh remove-fragment LIST_FILE   # alias по одному на строку (# комментарии ok)
#   ./fix-ssh-config-paths.sh list-hosts [FILE]           # список Host alias
#
# Опции:
#   --dry-run          только показать действия
#   --yes, -y          без интерактивного подтверждения
#   --user USER        User для всех Host из фрагмента (перекрывает User в файле)
#   --user ALIAS=USER  User для конкретного Host (можно повторять; перекрывает --user USER)
#   --identity-file F  путь к ключу в Windows-формате (add-host; по умолчанию id_ed25519)
#   --comment TEXT     комментарий перед блоком (add-host)
#   --win-config PATH  явный путь к Windows config
#   --wsl-config PATH  явный путь к WSL config
#
# Переменные окружения:
#   WIN_SSH_CONFIG, WSL_SSH_CONFIG, WSL_USER_HOME, WIN_USERNAME, SSH_DEFAULT_USER
#
# Пример (новые хосты, redis под ubuntu):
#   wsl bash .../fix-ssh-config-paths.sh apply-fragment .../extra-hosts.conf \
#     --user redis=ubuntu --user redis01=ubuntu --yes
#
# Пример (один хост):
#   wsl bash .../fix-ssh-config-paths.sh add-host myvm 10.0.1.100 --user ubuntu --yes && \
#   wsl bash .../fix-ssh-config-paths.sh sync-wsl --yes

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

DRY_RUN=0
ASSUME_YES=0
CMD=""
FRAGMENT=""
TARGET_FILE=""
WIN_SSH_CONFIG="${WIN_SSH_CONFIG:-}"
WSL_SSH_CONFIG="${WSL_SSH_CONFIG:-$HOME/.ssh/config}"
DEFAULT_SSH_USER="${SSH_DEFAULT_USER:-}"
SSH_USER_OVERRIDES=()
IDENTITY_FILE=""
HOST_COMMENT=""
SYNC_AFTER=0

log() { echo -e "$*"; }
warn() { echo -e "${YELLOW}$*${NC}"; }
err() { echo -e "${RED}$*${NC}" >&2; }
ok() { echo -e "${GREEN}$*${NC}"; }

resolve_win_username() {
    local u=""
    if [ -n "${WIN_USERNAME:-}" ]; then
        printf '%s' "$WIN_USERNAME"
        return 0
    fi
    if command -v whoami.exe >/dev/null 2>&1; then
        u=$(whoami.exe 2>/dev/null | tr -d '\r' || true)
    fi
    if [ -n "$u" ]; then
        u="${u##*\\}"
    fi
    if [ -z "$u" ] && command -v cmd.exe >/dev/null 2>&1; then
        u=$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r\n' || true)
    fi
    printf '%s' "$u"
}

resolve_win_ssh_config() {
    if [ -n "$WIN_SSH_CONFIG" ] && [ -f "$WIN_SSH_CONFIG" ]; then
        printf '%s' "$WIN_SSH_CONFIG"
        return 0
    fi
    local win_user
    win_user=$(resolve_win_username)
    if [ -z "$win_user" ]; then
        err "Не удалось определить пользователя Windows. Задать WIN_USERNAME или --win-config."
        exit 1
    fi
    printf '/mnt/c/Users/%s/.ssh/config' "$win_user"
}

resolve_default_identity_file() {
    local win_user
    win_user=$(resolve_win_username)
    if [ -n "$IDENTITY_FILE" ]; then
        printf '%s' "$IDENTITY_FILE"
        return 0
    fi
    printf 'C:\\Users\\%s\\.ssh\\id_ed25519' "$win_user"
}

apply_user_overrides_to_file() {
    local file="$1"
    local tmp out
    tmp=$(mktemp)

    if [ -n "$DEFAULT_SSH_USER" ]; then
        sed -E "s/^[[:space:]]*User[[:space:]]+.*/    User ${DEFAULT_SSH_USER}/" "$file" > "$tmp"
        cp "$tmp" "$file"
    fi

    local pair host user
    for pair in "${SSH_USER_OVERRIDES[@]}"; do
        host="${pair%%=*}"
        user="${pair#*=}"
        if [ -z "$host" ] || [ -z "$user" ] || [ "$host" = "$user" ]; then
            err "Неверный формат --user: $pair (ожидается ALIAS=USER)"
            rm -f "$tmp"
            exit 1
        fi
        out=$(mktemp)
        awk -v target="$host" -v new_user="$user" '
            /^[[:space:]]*Host[[:space:]]+/ {
                in_block=0
                for (i = 2; i <= NF; i++) {
                    gsub(/\r$/, "", $i)
                    if ($i == target) { in_block=1; break }
                }
            }
            in_block && /^[[:space:]]*User[[:space:]]+/ {
                sub(/\r$/, "", $0)
                sub(/User[[:space:]]+.*/, "User " new_user)
                in_block=0
            }
            { print }
        ' "$file" > "$out"
        mv "$out" "$file"
    done
    rm -f "$tmp"
}

prepare_fragment_copy() {
    local fragment="$1"
    local tmp
    tmp=$(mktemp)
    cp "$fragment" "$tmp"
    if [ -n "$DEFAULT_SSH_USER" ] || [ "${#SSH_USER_OVERRIDES[@]}" -gt 0 ]; then
        apply_user_overrides_to_file "$tmp"
    fi
    printf '%s' "$tmp"
}

render_host_block() {
    local alias="$1"
    local ip="$2"
    local user="$3"
    local key
    key=$(resolve_default_identity_file)
    if [ -n "$HOST_COMMENT" ]; then
        printf '# %s\n' "$HOST_COMMENT"
    fi
    cat <<EOF
Host ${alias}
    HostName ${ip}
    User ${user}
    IdentityFile ${key}
    IdentitiesOnly yes
    PreferredAuthentications publickey
EOF
}

set_users_in_win_config() {
    local win_cfg
    win_cfg=$(resolve_win_ssh_config)

    if [ ! -f "$win_cfg" ]; then
        err "Windows SSH config не найден: $win_cfg"
        exit 1
    fi
    if [ $# -lt 2 ] || [ $(($# % 2)) -ne 0 ]; then
        err "Использование: set-user HOST USER [HOST USER ...]"
        exit 1
    fi

    log "${CYAN}=== set-user ===${NC}"
    log "Windows config: $win_cfg"
    echo ""

    local pairs=()
    while [ $# -gt 0 ]; do
        pairs+=("$1=$2")
        ok "  $1 -> $2"
        shift 2
    done

    SSH_USER_OVERRIDES=("${pairs[@]}")
    DEFAULT_SSH_USER=""

    confirm_or_abort "Обновить User в Windows config?"

    if [ "$DRY_RUN" -eq 1 ]; then
        log "[dry-run] set-user в $win_cfg"
        return 0
    fi

    backup_file "$win_cfg"
    apply_user_overrides_to_file "$win_cfg"
    ok "User обновлён в $win_cfg"

    if [ "$SYNC_AFTER" -eq 1 ]; then
        sync_wsl_from_windows
    fi
}

add_host_to_win_config() {
    local alias="$1"
    local ip="$2"
    local user="${3:-admin}"
    local win_cfg
    win_cfg=$(resolve_win_ssh_config)

    if [ ! -f "$win_cfg" ]; then
        err "Windows SSH config не найден: $win_cfg"
        exit 1
    fi
    if host_exists_in_file "$alias" "$win_cfg"; then
        warn "Host уже есть: $alias (пропуск add-host)"
        return 0
    fi

    log "${CYAN}=== add-host ===${NC}"
    log "Alias: $alias"
    log "IP:    $ip"
    log "User:  $user"
    echo ""

    confirm_or_abort "Добавить Host в Windows config?"

    if [ "$DRY_RUN" -eq 1 ]; then
        render_host_block "$alias" "$ip" "$user"
        return 0
    fi

    backup_file "$win_cfg"
    {
        echo ""
        render_host_block "$alias" "$ip" "$user"
    } >> "$win_cfg"
    ok "Host $alias добавлен в $win_cfg"

    if [ "$SYNC_AFTER" -eq 1 ]; then
        sync_wsl_from_windows
    fi
}

remove_host_block_from_file() {
    local file="$1"
    local host="$2"
    local out
    out=$(mktemp)
    awk -v target="$host" '
        BEGIN { removing=0; pending_comment="" }
        /^[[:space:]]*Host[[:space:]]+/ {
            if (removing) removing=0
            if ($2 == target) {
                removing=1
                pending_comment=""
                next
            }
            if (pending_comment != "") {
                print pending_comment
                pending_comment=""
            }
            print
            next
        }
        removing {
            if ($0 ~ /^[[:space:]]*$/) { removing=0 }
            next
        }
        /^[[:space:]]*#/ {
            pending_comment=$0
            next
        }
        {
            if (pending_comment != "") {
                print pending_comment
                pending_comment=""
            }
            print
        }
        END {
            if (pending_comment != "" && !removing) print pending_comment
        }
    ' "$file" > "$out"
    mv "$out" "$file"
}

remove_hosts_from_file() {
    local file="$1"
    shift
    local host
    for host in "$@"; do
        [ -n "$host" ] || continue
        [[ "$host" =~ ^# ]] && continue
        if host_exists_in_file "$host" "$file"; then
            remove_host_block_from_file "$file" "$host"
            ok "  удалён: $host"
        else
            warn "  нет в config: $host"
        fi
    done
}

remove_hosts_from_win_config() {
    local win_cfg
    win_cfg=$(resolve_win_ssh_config)

    if [ ! -f "$win_cfg" ]; then
        err "Windows SSH config не найден: $win_cfg"
        exit 1
    fi
    if [ $# -eq 0 ]; then
        err "Указать Host alias: remove-host HOST [HOST ...] или remove-fragment FILE"
        exit 1
    fi

    log "${CYAN}=== remove-host ===${NC}"
    log "Windows config: $win_cfg"
    echo ""

    confirm_or_abort "Удалить Host-блоки из Windows config?"

    if [ "$DRY_RUN" -eq 1 ]; then
        log "[dry-run] remove: $*"
        return 0
    fi

    backup_file "$win_cfg"
    remove_hosts_from_file "$win_cfg" "$@"
    ok "Host-блоки удалены из $win_cfg"

    if [ "$SYNC_AFTER" -eq 1 ]; then
        sync_wsl_from_windows
    fi
}

remove_hosts_from_list_file() {
    local list_file="$1"
    local hosts=()

    if [ ! -f "$list_file" ]; then
        err "Файл не найден: $list_file"
        exit 1
    fi

    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%%#*}"
        line="$(echo "$line" | tr -d '[:space:]')"
        [ -n "$line" ] || continue
        hosts+=("$line")
    done < "$list_file"

    if [ "${#hosts[@]}" -eq 0 ]; then
        err "В $list_file нет Host alias"
        exit 1
    fi

    remove_hosts_from_win_config "${hosts[@]}"
}

resolve_windows_home() {
    local win_user windows_home=""
    win_user=$(resolve_win_username)
    if [ -n "${WSL_USER_HOME:-}" ]; then
        windows_home="$WSL_USER_HOME"
    elif [ -n "$win_user" ]; then
        windows_home="/mnt/c/Users/${win_user}"
    fi
    printf '%s' "$windows_home"
}

confirm_or_abort() {
    local prompt="$1"
    if [ "$ASSUME_YES" -eq 1 ] || [ "$DRY_RUN" -eq 1 ]; then
        return 0
    fi
    local reply=""
    if [ -t 0 ]; then
        read -r -p "$prompt [y/N]: " reply
    elif [ -e /dev/tty ]; then
        read -r -p "$prompt [y/N]: " reply < /dev/tty
    else
        warn "Нет TTY, продолжение без подтверждения (задать --yes для явного согласия)."
        return 0
    fi
    case "$reply" in
        y|Y|yes|YES) return 0 ;;
        *) err "Отменено."; exit 1 ;;
    esac
}

backup_file() {
    local f="$1"
    local bak="${f}.backup.$(date +%Y%m%d_%H%M%S)"
    if [ "$DRY_RUN" -eq 1 ]; then
        log "[dry-run] backup $f -> $bak"
        return 0
    fi
    cp "$f" "$bak"
    ok "Резервная копия: $bak"
}

list_host_aliases() {
    local f="$1"
    awk '
        /^[[:space:]]*Host[[:space:]]+/ {
            for (i = 2; i <= NF; i++) {
                if ($i != "*") print $i
            }
        }
    ' "$f" | sort -u
}

host_exists_in_file() {
    local host="$1"
    local f="$2"
    awk -v h="$host" '
        /^[[:space:]]*Host[[:space:]]+/ {
            for (i = 2; i <= NF; i++) {
                if ($i == h) { found=1; exit }
            }
        }
        END { exit(found ? 0 : 1) }
    ' "$f"
}

fix_paths_in_file() {
    local cfg="$1"
    local skip_backup="${2:-0}"
    local windows_home windows_user windows_home_esc
    windows_home=$(resolve_windows_home)
    windows_user=$(resolve_win_username)

    if [ ! -f "$cfg" ]; then
        err "Файл не найден: $cfg"
        exit 1
    fi

    if [ "$DRY_RUN" -eq 0 ] && [ "$skip_backup" -eq 0 ]; then
        backup_file "$cfg"
    fi

    local tmp
    tmp=$(mktemp)
    cp "$cfg" "$tmp"

    if [ -n "$windows_home" ]; then
        sed -i "s|${windows_home}/.ssh/|${HOME}/.ssh/|g" "$tmp"
    fi

    if [ -n "$windows_user" ]; then
        sed -i "s|C:/Users/${windows_user}/.ssh/|${HOME}/.ssh/|g" "$tmp"
        sed -i "s|C:\\\\Users\\\\${windows_user}\\\\.ssh\\\\|${HOME}/.ssh/|g" "$tmp"
    fi

    sed -i "s|C:/Users/[^/]*/.ssh/|${HOME}/.ssh/|g" "$tmp"
    sed -i "s|C:\\\\Users\\\\[^\\\\]*\\\\.ssh\\\\|${HOME}/.ssh/|g" "$tmp"
    sed -i "s|IdentityFile ~/.ssh/|IdentityFile ${HOME}/.ssh/|g" "$tmp"
    sed -i "s|IdentityFile \"~/.ssh/|IdentityFile \"${HOME}/.ssh/|g" "$tmp"

    if [ "$DRY_RUN" -eq 1 ]; then
        log "[dry-run] fix-paths для $cfg"
        grep -n "IdentityFile" "$tmp" | head -15 || true
        rm -f "$tmp"
        return 0
    fi

    mv "$tmp" "$cfg"
    ok "Пути IdentityFile исправлены в $cfg"
}

add_fragment_to_win_config() {
    local fragment="$1"
    local win_cfg
    win_cfg=$(resolve_win_ssh_config)

    if [ ! -f "$fragment" ]; then
        err "Фрагмент не найден: $fragment"
        exit 1
    fi
    if [ ! -f "$win_cfg" ]; then
        err "Windows SSH config не найден: $win_cfg"
        exit 1
    fi

    log "${CYAN}=== add-fragment ===${NC}"
    log "Windows config: $win_cfg"
    log "Фрагмент:       $fragment"
    if [ -n "$DEFAULT_SSH_USER" ]; then
        log "User (все Host): $DEFAULT_SSH_USER"
    fi
    if [ "${#SSH_USER_OVERRIDES[@]}" -gt 0 ]; then
        log "User (per-host): ${SSH_USER_OVERRIDES[*]}"
    fi
    echo ""

    local prepared
    prepared=$(prepare_fragment_copy "$fragment")

    local to_add=()
    local skipped=()
    local host
    while IFS= read -r host; do
        [ -n "$host" ] || continue
        if host_exists_in_file "$host" "$win_cfg"; then
            skipped+=("$host")
        else
            to_add+=("$host")
        fi
    done < <(list_host_aliases "$prepared")

    if [ "${#skipped[@]}" -gt 0 ]; then
        warn "Уже есть в config (${#skipped[@]}): ${skipped[*]}"
    fi
    if [ "${#to_add[@]}" -eq 0 ]; then
        rm -f "$prepared"
        warn "Новых Host для добавления нет."
        return 0
    fi

    ok "Будет добавлено (${#to_add[@]}): ${to_add[*]}"
    confirm_or_abort "Добавить фрагмент в Windows config?"

    if [ "$DRY_RUN" -eq 1 ]; then
        log "[dry-run] append prepared fragment -> $win_cfg"
        cat "$prepared"
        rm -f "$prepared"
        return 0
    fi

    backup_file "$win_cfg"
    {
        echo ""
        cat "$prepared"
    } >> "$win_cfg"
    rm -f "$prepared"
    ok "Фрагмент добавлен в $win_cfg"
}

sync_wsl_from_windows() {
    local win_cfg wsl_cfg
    win_cfg=$(resolve_win_ssh_config)
    wsl_cfg="$WSL_SSH_CONFIG"

    log "${CYAN}=== sync-wsl ===${NC}"
    log "Источник (Windows): $win_cfg"
    log "Назначение (WSL):   $wsl_cfg"
    echo ""

    if [ ! -f "$win_cfg" ]; then
        err "Windows config не найден: $win_cfg"
        exit 1
    fi

    confirm_or_abort "Скопировать Windows config в WSL и исправить пути?"

    if [ "$DRY_RUN" -eq 1 ]; then
        log "[dry-run] cp $win_cfg -> $wsl_cfg; fix-paths"
        return 0
    fi

    mkdir -p "$(dirname "$wsl_cfg")"
    chmod 700 "$(dirname "$wsl_cfg")"
    if [ -f "$wsl_cfg" ]; then
        backup_file "$wsl_cfg"
    fi
    cp "$win_cfg" "$wsl_cfg"
    chmod 600 "$wsl_cfg"
    fix_paths_in_file "$wsl_cfg" 1
    ok "WSL config обновлён: $wsl_cfg"
}

usage() {
    sed -n '1,35p' "$0"
}

ARGS=("$@")
PARSED=()
i=0
while [ $i -lt ${#ARGS[@]} ]; do
    arg="${ARGS[$i]}"
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        --yes|-y) ASSUME_YES=1 ;;
        --win-config)
            i=$((i + 1))
            WIN_SSH_CONFIG="${ARGS[$i]}"
            ;;
        --wsl-config)
            i=$((i + 1))
            WSL_SSH_CONFIG="${ARGS[$i]}"
            ;;
        --user)
            i=$((i + 1))
            if [[ "${ARGS[$i]:-}" == *"="* ]]; then
                SSH_USER_OVERRIDES+=("${ARGS[$i]}")
            else
                DEFAULT_SSH_USER="${ARGS[$i]}"
            fi
            ;;
        --identity-file|--key)
            i=$((i + 1))
            IDENTITY_FILE="${ARGS[$i]}"
            ;;
        --comment)
            i=$((i + 1))
            HOST_COMMENT="${ARGS[$i]}"
            ;;
        --sync|--sync-wsl)
            SYNC_AFTER=1
            ;;
        help|-h|--help)
            CMD="help"
            ;;
        fix-paths|add-fragment|sync-wsl|apply-fragment|list-hosts|add-host|set-user|remove-host|remove-fragment)
            CMD="$arg"
            ;;
        *)
            PARSED+=("$arg")
            ;;
    esac
    i=$((i + 1))
done
set -- "${PARSED[@]}"

if [ -z "$CMD" ] || [ "$CMD" = "help" ] || [ "$CMD" = "-h" ] || [ "$CMD" = "--help" ]; then
    usage
    exit 0
fi

case "$CMD" in
    fix-paths)
        TARGET_FILE="${1:-$WSL_SSH_CONFIG}"
        fix_paths_in_file "$TARGET_FILE"
        ;;
    add-fragment)
        FRAGMENT="${1:-}"
        if [ -z "$FRAGMENT" ]; then
            err "Указать путь к фрагменту: add-fragment FILE"
            exit 1
        fi
        add_fragment_to_win_config "$FRAGMENT"
        ;;
    sync-wsl)
        sync_wsl_from_windows
        ;;
    apply-fragment)
        FRAGMENT="${1:-}"
        if [ -z "$FRAGMENT" ]; then
            err "Указать путь к фрагменту: apply-fragment FILE"
            exit 1
        fi
        add_fragment_to_win_config "$FRAGMENT"
        sync_wsl_from_windows
        ;;
    add-host)
        if [ -z "${1:-}" ] || [ -z "${2:-}" ]; then
            err "Использование: add-host ALIAS IP [--user USER] [--sync] [--yes]"
            exit 1
        fi
        add_host_to_win_config "$1" "$2" "${DEFAULT_SSH_USER:-admin}"
        ;;
    set-user)
        if [ $# -lt 2 ]; then
            err "Использование: set-user HOST USER [HOST USER ...] [--sync] [--yes]"
            exit 1
        fi
        set_users_in_win_config "$@"
        ;;
    remove-host)
        if [ $# -eq 0 ]; then
            err "Использование: remove-host HOST [HOST ...] [--sync] [--yes]"
            exit 1
        fi
        remove_hosts_from_win_config "$@"
        ;;
    remove-fragment)
        if [ -z "${1:-}" ]; then
            err "Использование: remove-fragment LIST_FILE [--sync] [--yes]"
            exit 1
        fi
        remove_hosts_from_list_file "$1"
        ;;
    list-hosts)
        TARGET_FILE="${1:-$(resolve_win_ssh_config)}"
        list_host_aliases "$TARGET_FILE"
        ;;
    *)
        err "Неизвестная команда: $CMD"
        usage
        exit 1
        ;;
esac
