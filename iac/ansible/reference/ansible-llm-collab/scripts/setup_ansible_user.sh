#!/usr/bin/env bash
# Run on the target server as a user with sudo.
# Creates the ansible user, grants NOPASSWD sudo, sets a random 25-character password,
# appends the given public key to authorized_keys. Password is saved under /tmp.
# Usage: $0 [username] <path_to_public_key_file> [set_password]
# set_password: yes — set a new password and write it to /tmp; no — leave the password unchanged (for an existing user).
set -euo pipefail

USER_NAME="${1:-ansible}"
PUBKEY_FILE="${2:-}"
SET_PASSWORD="${3:-yes}"
CRED_FILE="/tmp/ansible_user_credentials.txt"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run the script with sudo (for example: sudo bash $0)." >&2
  exit 1
fi

if [[ -z "$PUBKEY_FILE" || ! -f "$PUBKEY_FILE" ]]; then
  echo "Pass the path to the public key file: $0 $USER_NAME /path/to/key.pub" >&2
  exit 1
fi

# Create the user when missing
if ! id -u "$USER_NAME" &>/dev/null; then
  useradd -m -s /bin/bash "$USER_NAME"
  echo "User $USER_NAME created."
else
  echo "User $USER_NAME already exists."
fi

USER_HOME=$(getent passwd "$USER_NAME" | cut -d: -f6)

# Passwordless sudo
SUDOERS_FILE="/etc/sudoers.d/$USER_NAME"
echo "$USER_NAME ALL=(ALL) NOPASSWD:ALL" > "$SUDOERS_FILE"
chmod 0440 "$SUDOERS_FILE"
echo "Sudo NOPASSWD configured: $SUDOERS_FILE"

if [[ "${SET_PASSWORD,,}" == "yes" ]]; then
  PASSWORD=$(openssl rand -base64 25 | tr -dc 'A-Za-z0-9' | head -c 25)
  echo "$USER_NAME:$PASSWORD" | chpasswd
  echo "Password set."
fi

# .ssh and authorized_keys: append the given public key
mkdir -p "$USER_HOME/.ssh"
chmod 700 "$USER_HOME/.ssh"
cat "$PUBKEY_FILE" >> "$USER_HOME/.ssh/authorized_keys"
chmod 600 "$USER_HOME/.ssh/authorized_keys"
chown -R "$USER_NAME:$USER_NAME" "$USER_HOME/.ssh"
echo "Public key added to $USER_HOME/.ssh/authorized_keys"

if [[ "${SET_PASSWORD,,}" == "yes" ]]; then
  {
    echo "host=$(hostname)"
    echo "user=$USER_NAME"
    echo "password=$PASSWORD"
  } > "$CRED_FILE"
  chmod 0600 "$CRED_FILE"
  echo "Password saved in $CRED_FILE — copy it into Vault and delete the file on the server."
fi
