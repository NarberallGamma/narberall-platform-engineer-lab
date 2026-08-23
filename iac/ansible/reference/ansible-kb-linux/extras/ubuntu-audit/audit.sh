#!/bin/bash

OUT="ubuntu_audit_$(hostname)_$(date +%Y%m%d_%H%M%S).log"
exec &> >(tee "$OUT")

echo "=== [SYSTEM INFORMATION] ==="
lsb_release -a
uname -a
uptime
df -h
free -h

echo -e "\n=== [CPU AND MEMORY] ==="
lscpu
echo
grep -E 'MemTotal|SwapTotal' /proc/meminfo

echo -e "\n=== [DISKS AND PARTITIONS] ==="
lsblk -f
mount | grep '^/dev'

echo -e "\n=== [NETWORK] ==="
ip a
ip r
cat /etc/netplan/*.yaml 2>/dev/null || cat /etc/network/interfaces 2>/dev/null

echo -e "\n=== [DNS AND HOSTNAME] ==="
cat /etc/resolv.conf
hostnamectl

echo -e "\n=== [OPEN PORTS] ==="
ss -tuln

echo -e "\n=== [FIREWALLS] ==="
ufw status verbose
iptables -L -n -v

echo -e "\n=== [INSTALLED PACKAGES] ==="
dpkg -l | grep -v ^rc | wc -l
dpkg -l | grep -v ^rc | awk '{print $2}' | sort

echo -e "\n=== [THIRD-PARTY REPOSITORIES (PPA)] ==="
grep -r ^ /etc/apt/sources.list /etc/apt/sources.list.d/

echo -e "\n=== [AVAILABLE UPDATES] ==="
apt update > /dev/null
apt list --upgradable

echo -e "\n=== [INSTALLED KERNELS] ==="
dpkg --list | grep linux-image
uname -r

echo -e "\n=== [INSTALLED SYSTEMD SERVICES] ==="
systemctl list-units --type=service --all

echo -e "\n=== [ACTIVE PROCESSES] ==="
ps aux --sort=-%mem | head -n 20

echo -e "\n=== [DOCKER (if installed)] ==="
if command -v docker &>/dev/null; then
    docker ps -a
    docker images
    docker network ls
else
    echo "Docker is not installed"
fi

echo -e "\n=== [KUBERNETES (if installed)] ==="
if command -v kubectl &>/dev/null; then
    kubectl get nodes -o wide
    kubectl get pods --all-namespaces
else
    echo "Kubernetes is not installed"
fi

echo -e "\n=== [MySQL / PostgreSQL (if present)] ==="
systemctl status mysql 2>/dev/null || echo "MySQL is not installed"
systemctl status postgresql 2>/dev/null || echo "PostgreSQL is not installed"

echo -e "\n=== [AUTOSTART] ==="
systemctl list-unit-files --state=enabled

echo -e "\n=== [FAILED SERVICES] ==="
systemctl list-units --failed

echo -e "\n=== [CRON JOBS] ==="
ls -l /etc/cron* /var/spool/cron/crontabs 2>/dev/null

echo -e "\n=== [SELINUX / AppArmor] ==="
sestatus 2>/dev/null || echo "SELinux is not in use"
aa-status 2>/dev/null || echo "AppArmor is not active"

echo -e "\n=== [SYSTEM CONFIGS] ==="
ls -1 /etc | grep -E 'network|netplan|systemd|ssh|mysql|nginx|cron'

echo -e "\n=== [AUDIT COMPLETE] ==="
echo "Report saved to: $OUT"
