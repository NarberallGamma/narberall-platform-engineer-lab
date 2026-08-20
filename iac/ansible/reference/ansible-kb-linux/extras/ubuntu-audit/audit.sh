#!/bin/bash

OUT="ubuntu_audit_$(hostname)_$(date +%Y%m%d_%H%M%S).log"
exec &> >(tee "$OUT")

echo "=== [СИСТЕМНАЯ ИНФОРМАЦИЯ] ==="
lsb_release -a
uname -a
uptime
df -h
free -h

echo -e "\n=== [ЦП и ПАМЯТЬ] ==="
lscpu
echo
grep -E 'MemTotal|SwapTotal' /proc/meminfo

echo -e "\n=== [ДИСКИ И РАЗДЕЛЫ] ==="
lsblk -f
mount | grep '^/dev'

echo -e "\n=== [СЕТЬ] ==="
ip a
ip r
cat /etc/netplan/*.yaml 2>/dev/null || cat /etc/network/interfaces 2>/dev/null

echo -e "\n=== [DNS и HOSTNAME] ==="
cat /etc/resolv.conf
hostnamectl

echo -e "\n=== [ОТКРЫТЫЕ ПОРТЫ] ==="
ss -tuln

echo -e "\n=== [ФАЙЕРВОЛЫ] ==="
ufw status verbose
iptables -L -n -v

echo -e "\n=== [УСТАНОВЛЕННЫЕ ПАКЕТЫ] ==="
dpkg -l | grep -v ^rc | wc -l
dpkg -l | grep -v ^rc | awk '{print $2}' | sort

echo -e "\n=== [СТОРОННИЕ РЕПОЗИТОРИИ (PPA)] ==="
grep -r ^ /etc/apt/sources.list /etc/apt/sources.list.d/

echo -e "\n=== [ДОСТУПНЫЕ ОБНОВЛЕНИЯ] ==="
apt update > /dev/null
apt list --upgradable

echo -e "\n=== [УСТАНОВЛЕННЫЕ ЯДРА] ==="
dpkg --list | grep linux-image
uname -r

echo -e "\n=== [УСТАНОВЛЕННЫЕ СЛУЖБЫ systemd] ==="
systemctl list-units --type=service --all

echo -e "\n=== [АКТИВНЫЕ ПРОЦЕССЫ] ==="
ps aux --sort=-%mem | head -n 20

echo -e "\n=== [DOCKER (если установлен)] ==="
if command -v docker &>/dev/null; then
    docker ps -a
    docker images
    docker network ls
else
    echo "Docker не установлен"
fi

echo -e "\n=== [KUBERNETES (если установлен)] ==="
if command -v kubectl &>/dev/null; then
    kubectl get nodes -o wide
    kubectl get pods --all-namespaces
else
    echo "Kubernetes не установлен"
fi

echo -e "\n=== [MySQL / PostgreSQL (если есть)] ==="
systemctl status mysql 2>/dev/null || echo "MySQL не установлен"
systemctl status postgresql 2>/dev/null || echo "PostgreSQL не установлен"

echo -e "\n=== [АВТОЗАПУСК] ==="
systemctl list-unit-files --state=enabled

echo -e "\n=== [НЕИСПРАВНЫЕ СЛУЖБЫ] ==="
systemctl list-units --failed

echo -e "\n=== [CRON JOBS] ==="
ls -l /etc/cron* /var/spool/cron/crontabs 2>/dev/null

echo -e "\n=== [SELINUX / AppArmor] ==="
sestatus 2>/dev/null || echo "SELinux не используется"
aa-status 2>/dev/null || echo "AppArmor не активен"

echo -e "\n=== [КОНФИГИ СИСТЕМЫ] ==="
ls -1 /etc | grep -E 'network|netplan|systemd|ssh|mysql|nginx|cron'

echo -e "\n=== [АУДИТ ЗАВЕРШЕН] ==="
echo "Отчёт сохранён в файл: $OUT"
