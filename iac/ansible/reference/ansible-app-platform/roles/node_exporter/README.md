# Role to install node_exporter (Prometheus client).

Installs node_exporter from the prometheus.io RPM repository and applies the following:

 - adds --collector.textfile.directory (running process looks like: /usr/bin/node_exporter --collector.textfile.directory=/var/run/prometheus/)

 - adds directory /etc/prometheus/scripts

 - /etc/prometheus/scripts/main.sh  - script started from cron

 - /etc/prometheus/scripts/list_of_checks - either all:smartmon or one line per host as hostname1:check1 check2 check3

 - /etc/prometheus/scripts/smartmon.sh - script that runs SMART commands

 - /var/run/prometheus/smartmon.prom - output of the sh script; those metrics are then added to node_exporter metrics


Debian-based tasks are taken from:
 - https://github.com/UnderGreen/ansible-prometheus-exporters-common
 - https://github.com/UnderGreen/ansible-prometheus-node-exporter
