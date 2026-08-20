#!/usr/bin/env bash
# Запускать на целевом сервере пользователем с доступом к sudo.
# Создаёт пользователя ansible, даёт NOPASSWD sudo, ставит случайный пароль 25 символов,
# добавляет переданный открытый ключ в authorized_keys. Пароль сохраняет в /tmp.
# Вызов: $0 [username] <путь_к_файлу_с_открытым_ключом> [set_password]
# set_password: yes — задать новый пароль и записать в /tmp; no — не трогать пароль (для уже существующего пользователя).
set -euo pipefail

USER_NAME="${1:-ansible}"
PUBKEY_FILE="${2:-}"
SET_PASSWORD="${3:-yes}"
CRED_FILE="/tmp/ansible_user_credentials.txt"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Запустите скрипт с правами sudo (например: sudo bash $0)." >&2
  exit 1
fi

if [[ -z "$PUBKEY_FILE" || ! -f "$PUBKEY_FILE" ]]; then
  echo "Укажите путь к файлу с открытым ключом: $0 $USER_NAME /path/to/key.pub" >&2
  exit 1
fi

# Создать пользователя, если ещё нет
if ! id -u "$USER_NAME" &>/dev/null; then
  useradd -m -s /bin/bash "$USER_NAME"
  echo "Пользователь $USER_NAME создан."
else
  echo "Пользователь $USER_NAME уже существует."
fi

USER_HOME=$(getent passwd "$USER_NAME" | cut -d: -f6)

# Sudo без пароля
SUDOERS_FILE="/etc/sudoers.d/$USER_NAME"
echo "$USER_NAME ALL=(ALL) NOPASSWD:ALL" > "$SUDOERS_FILE"
chmod 0440 "$SUDOERS_FILE"
echo "Sudo NOPASSWD настроен: $SUDOERS_FILE"

if [[ "${SET_PASSWORD,,}" == "yes" ]]; then
  PASSWORD=$(openssl rand -base64 25 | tr -dc 'A-Za-z0-9' | head -c 25)
  echo "$USER_NAME:$PASSWORD" | chpasswd
  echo "Пароль установлен."
fi

# .ssh и authorized_keys: добавить переданный открытый ключ
mkdir -p "$USER_HOME/.ssh"
chmod 700 "$USER_HOME/.ssh"
cat "$PUBKEY_FILE" >> "$USER_HOME/.ssh/authorized_keys"
chmod 600 "$USER_HOME/.ssh/authorized_keys"
chown -R "$USER_NAME:$USER_NAME" "$USER_HOME/.ssh"
echo "Открытый ключ добавлен в $USER_HOME/.ssh/authorized_keys"

if [[ "${SET_PASSWORD,,}" == "yes" ]]; then
  {
    echo "host=$(hostname)"
    echo "user=$USER_NAME"
    echo "password=$PASSWORD"
  } > "$CRED_FILE"
  chmod 0600 "$CRED_FILE"
  echo "Пароль сохранён в $CRED_FILE — скопируйте в Vault и удалите файл на сервере."
fi
