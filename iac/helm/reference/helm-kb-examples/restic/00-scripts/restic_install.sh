#!/usr/bin/env bash

export DEBIAN_FRONTEND=noninteractive

if [[ $(which restic | wc -l) == 1 ]]; then
  if [[ $(restic version | grep '0.12' | wc -l) == 1 ]]; then
    exit 0;
  else
    mv /usr/bin/restic /usr/bin/restic.old;
  fi
fi

function install_restic {
  wget -q https://github.com/restic/restic/releases/download/v0.12.0/restic_0.12.0_linux_amd64.bz2 -O /tmp/restic_0.12.0_linux_amd64.bz2
  test -s /tmp/restic_0.12.0_linux_amd64.bz2 || \
    curl -sL https://github.com/restic/restic/releases/download/v0.12.0/restic_0.12.0_linux_amd64.bz2 > /tmp/restic_0.12.0_linux_amd64.bz2
  test -s /tmp/restic_0.12.0_linux_amd64.bz2 || { echo '### Failed to install restic!'; exit 1 ; }

  /bin/bzcat /tmp/restic_0.12.0_linux_amd64.bz2 > /usr/local/bin/restic_0.12.0_linux_amd64

  chown root:root /usr/local/bin/restic_0.12.0_linux_amd64
  chmod 755 /usr/local/bin/restic_0.12.0_linux_amd64
  ln -s /usr/local/bin/restic_0.12.0_linux_amd64 /usr/bin/restic
}

# main
install_restic
