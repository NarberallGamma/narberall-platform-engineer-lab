#!/usr/bin/env bash
# Normalize IdentityFile entries in ~/.ssh/config to $HOME/.ssh on a Linux control node.
#
# Usage:
#   ./fix_ssh_config_paths.sh
#
# Optional environment:
#   SSH_CONFIG  - SSH config path (default: ~/.ssh/config)
#   SSH_KEYS_DIR - key directory (default: ~/.ssh)

set -euo pipefail

SSH_CONFIG="${SSH_CONFIG:-$HOME/.ssh/config}"
SSH_CONFIG_BACKUP="$HOME/.ssh/config.backup.$(date +%Y%m%d_%H%M%S)"
SSH_KEYS_DIR="${SSH_KEYS_DIR:-$HOME/.ssh}"

if [ ! -f "$SSH_CONFIG" ]; then
    echo "SSH config not found: $SSH_CONFIG"
    exit 1
fi

cp "$SSH_CONFIG" "$SSH_CONFIG_BACKUP"

# Expand ~ and relative .ssh paths on IdentityFile lines.
sed -i "s|IdentityFile ~/.ssh/|IdentityFile $HOME/.ssh/|g" "$SSH_CONFIG"
sed -i "s|IdentityFile \"~/.ssh/|IdentityFile \"$HOME/.ssh/|g" "$SSH_CONFIG"
sed -i "s|IdentityFile \\.ssh/|IdentityFile $HOME/.ssh/|g" "$SSH_CONFIG"
sed -i "s|IdentityFile \"\\.ssh/|IdentityFile \"$HOME/.ssh/|g" "$SSH_CONFIG"

echo "Updated IdentityFile paths in $SSH_CONFIG"
echo "Backup: $SSH_CONFIG_BACKUP"
