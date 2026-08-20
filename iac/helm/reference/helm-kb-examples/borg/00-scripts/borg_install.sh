#!/usr/bin/env bash

export DEBIAN_FRONTEND=noninteractive
export BORG_VER="1.1.17"
export BORG_URL="https://github.com/borgbackup/borg/releases/download/${BORG_VER}/borg-linux64"

BORG_CHK=$(borg --version 2>/dev/null) 
[[ "${BORG_CHK}" =~ "${BORG_VER}" ]] && exit 0

function install_borg {
  rm -f /usr/local/bin/borg 
  wget -q "${BORG_URL}" -O /usr/local/bin/borg
  test -s /usr/local/bin/borg || \
    curl -sL "${BORG_URL}" > /usr/local/bin/borg
  test -s /usr/local/bin/borg || { echo '### Failed to install borg!'; exit 1 ; }

  chown root:root /usr/local/bin/borg
  chmod 755 /usr/local/bin/borg
  ln -sf /usr/local/bin/borg /usr/bin/borg
  ln -sf /usr/local/bin/borg /usr/bin/borgfs
}

# main
install_borg
