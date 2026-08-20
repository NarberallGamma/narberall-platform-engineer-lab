# Роль для установки nodex_exporter(клиент prometheus).

Устанавливается node_exporter из rpm репозитория prometheus.io и делаются следующие действия:

 - добавлялется опция --collector.textfile.directory (запущенный процесс будет выглядить так: /usr/bin/node_exporter --collector.textfile.directory=/var/run/prometheus/)

 - добавляется каталог /etc/prometheus/scripts

 - /etc/prometheus/scripts/main.sh  - скрипт для запуска через cron

 - /etc/prometheus/scripts/list_of_checks - в виде all:smartmon или в столбик hostname1:check1 check2 check3, для каждого хоста своя строка

 - /etc/prometheus/scripts/smartmon.sh - скрипт для запуск smart команд

 - /var/run/prometheus/smartmon.prom -  результат работы sh  скрипта,далее  метрики этoго скрипта будут добавлены метрикам node_exporter


Для debian-based таски взяты отсюда:
 - https://github.com/UnderGreen/ansible-prometheus-exporters-common
 - https://github.com/UnderGreen/ansible-prometheus-node-exporter
