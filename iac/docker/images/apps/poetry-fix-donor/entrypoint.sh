#!/usr/bin/env bash

# Create FIX and stunnel configs
python ./market_feed/create_configs.py

# Copy configs into stunnel paths
cp ./market_feed/stunnel.conf /etc/stunnel
cp ./market_feed/stunnel4 /etc/default/stunnel

service stunnel4 start
python ./market_feed/client.py
