#!/bin/sh
set -e

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*"; }

CONFIG_FILE="${CONFIG_FILE:-/config/ssh-tunnel.conf}"

# Load from config file if present (overrides env)
if [ -f "$CONFIG_FILE" ]; then
    log "Using config: $CONFIG_FILE"
    while IFS= read -r line; do
        case "$line" in
            HOST=*) SSH_HOST="${line#HOST=}";;
            USER=*) SSH_USER="${line#USER=}";;
            KEY_PATH=*) SSH_KEY_PATH="${line#KEY_PATH=}";;
        esac
    done < "$CONFIG_FILE"
    # Trim CRLF from values (config may be mounted from Windows)
    [ -n "$SSH_HOST" ] && SSH_HOST=$(echo "$SSH_HOST" | tr -d '\r')
    [ -n "$SSH_USER" ] && SSH_USER=$(echo "$SSH_USER" | tr -d '\r')
    [ -n "$SSH_KEY_PATH" ] && SSH_KEY_PATH=$(echo "$SSH_KEY_PATH" | tr -d '\r')
fi

SSH_KEY_PATH="${SSH_KEY_PATH:-/config/key}"

if [ -z "$SSH_HOST" ] || [ -z "$SSH_USER" ] || [ ! -f "$SSH_KEY_PATH" ]; then
    log "Error: need SSH_HOST, SSH_USER and key. Use -e SSH_HOST=... -e SSH_USER=... -v /path/to/key:/config/key:ro"
    log "  Or mount ssh-tunnel.conf at /config/ssh-tunnel.conf (with HOST=, USER=, KEY_PATH=/config/key)"
    exit 1
fi

# Use a copy of the key so we can chmod 600 (mounted key often has 0777 and SSH rejects it)
KEY_PRIVATE="/tmp/ssh-key.$$"
cp "$SSH_KEY_PATH" "$KEY_PRIVATE" && chmod 600 "$KEY_PRIVATE"
SSH_KEY_PATH="$KEY_PRIVATE"
REMOTE_PORT="${REMOTE_PORT:-10443}"
ROTATE_MIN="${ROTATE_MIN:-10}"
ROTATE_SEC=$((ROTATE_MIN * 60))

start_tunnel() {
    local port=$1
    ssh -i "$SSH_KEY_PATH" -N \
        -o ConnectTimeout=15 \
        -o ServerAliveInterval=30 \
        -o ServerAliveCountMax=3 \
        -o ExitOnForwardFailure=yes \
        -o StrictHostKeyChecking=accept-new \
        -o BatchMode=yes \
        -L "${port}:localhost:${REMOTE_PORT}" \
        "${SSH_USER}@${SSH_HOST}" &
    echo $!
}

# Start six tunnels
PID1=$(start_tunnel 10809)
PID2=$(start_tunnel 10810)
PID3=$(start_tunnel 10811)
PID4=$(start_tunnel 10812)
PID5=$(start_tunnel 10813)
PID6=$(start_tunnel 10814)
log "Tunnels started: 10809=$PID1, 10810=$PID2, 10811=$PID3, 10812=$PID4, 10813=$PID5, 10814=$PID6"
sleep 5

# Start nginx (balancer) - listens 10808, round-robin to 10809..10814
nginx -g "daemon off;" &
NGINX_PID=$!

# Wait for port to be free (port in TIME_WAIT after ssh exit causes "Address in use"; on Windows/Docker often 120s+)
PORT_REUSE_DELAY_RESTART=120

# Restart one tunnel every ROTATE_MIN (rotate 1 -> 2 -> ... -> 6 -> 1). Use same long delay as restart path (Windows TIME_WAIT).
rotate_one() {
    case $NEXT in
        1) kill $PID1 2>/dev/null || true; sleep $PORT_REUSE_DELAY_RESTART; PID1=$(start_tunnel 10809); log "Rotated tunnel 1"; NEXT=2;;
        2) kill $PID2 2>/dev/null || true; sleep $PORT_REUSE_DELAY_RESTART; PID2=$(start_tunnel 10810); log "Rotated tunnel 2"; NEXT=3;;
        3) kill $PID3 2>/dev/null || true; sleep $PORT_REUSE_DELAY_RESTART; PID3=$(start_tunnel 10811); log "Rotated tunnel 3"; NEXT=4;;
        4) kill $PID4 2>/dev/null || true; sleep $PORT_REUSE_DELAY_RESTART; PID4=$(start_tunnel 10812); log "Rotated tunnel 4"; NEXT=5;;
        5) kill $PID5 2>/dev/null || true; sleep $PORT_REUSE_DELAY_RESTART; PID5=$(start_tunnel 10813); log "Rotated tunnel 5"; NEXT=6;;
        6) kill $PID6 2>/dev/null || true; sleep $PORT_REUSE_DELAY_RESTART; PID6=$(start_tunnel 10814); log "Rotated tunnel 6"; NEXT=1;;
        *) NEXT=1;;
    esac
}

# Return 0 if process is dead (gone or zombie). Background ssh that exited becomes zombie until reaped; kill -0 still succeeds for zombies.
is_process_dead() {
    _p=$1
    if ! kill -0 "$_p" 2>/dev/null; then
        return 0
    fi
    [ -f "/proc/$_p/stat" ] || return 1
    _state=$(awk '{print $3}' "/proc/$_p/stat" 2>/dev/null)
    [ "$_state" = "Z" ]
}

# Restart a single dead tunnel. Wait PORT_REUSE_DELAY_RESTART so port leaves TIME_WAIT (else "Address in use" on Windows/Docker).
# Up to 3 attempts with long wait between (Windows often keeps TIME_WAIT 120s).
restart_if_dead() {
    _pid=$1
    _port=$2
    if is_process_dead "$_pid"; then
        log "Tunnel $_port (pid $_pid) dead, restarting in ${PORT_REUSE_DELAY_RESTART}s..."
        for _attempt in 1 2 3; do
            sleep $PORT_REUSE_DELAY_RESTART
            _new_pid=$(start_tunnel "$_port")
            sleep 3
            if ! is_process_dead "$_new_pid"; then
                echo "$_new_pid"
                return
            fi
            [ "$_attempt" -lt 3 ] && log "Tunnel $_port restart failed (port in use?), retrying in ${PORT_REUSE_DELAY_RESTART}s..."
        done
        log "Tunnel $_port restart failed after 3 attempts, will retry next cycle"
        echo "$_pid"
    else
        echo "$_pid"
    fi
}

CHECK_INTERVAL=30
LAST_ROTATE=$(date +%s)
NEXT=1

while kill -0 $NGINX_PID 2>/dev/null; do
    sleep $CHECK_INTERVAL

    # Restart any dead tunnels (one by one with delay to avoid sshd rate limit)
    PID1=$(restart_if_dead "$PID1" 10809)
    PID2=$(restart_if_dead "$PID2" 10810)
    PID3=$(restart_if_dead "$PID3" 10811)
    PID4=$(restart_if_dead "$PID4" 10812)
    PID5=$(restart_if_dead "$PID5" 10813)
    PID6=$(restart_if_dead "$PID6" 10814)

    # Rotate one tunnel on schedule (same as before)
    now=$(date +%s)
    if [ $((now - LAST_ROTATE)) -ge $ROTATE_SEC ]; then
        LAST_ROTATE=$now
        rotate_one
    fi
done

log "Nginx exited, stopping."
