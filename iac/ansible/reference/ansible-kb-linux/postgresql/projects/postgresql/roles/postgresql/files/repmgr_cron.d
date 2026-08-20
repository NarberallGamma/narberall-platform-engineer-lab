# File under ansible control
0 * * * * postgres /usr/bin/repmgr -f /etc/repmgr.conf cluster cleanup -k 7 2>&1 | logger -it repmgr-cluster-cleanup
# Fix file description leak in repmgrd
0 * * * * root /bin/systemctl restart repmgrd.service
