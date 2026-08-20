#!/usr/bin/env bash

if type yum; then
  yum list installed > /tmp/packages
else
  which dpkg && dpkg -l > /tmp/packages
fi
