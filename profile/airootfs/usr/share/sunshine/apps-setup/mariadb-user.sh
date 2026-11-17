#!/usr/bin/env bash
# MariaDB for MySQL Workbench: initialise the data directory, start the server, create a database user named like the account (socket login: no extra password to remember).
# args: id user home   (runs as root)
ID=$1; U=$2; H=$3
[ -d /var/lib/mysql/mysql ] || mariadb-install-db --user=mysql --basedir=/usr --datadir=/var/lib/mysql
systemctl enable --now mariadb.service
for i in $(seq 1 20); do mariadb-admin ping >/dev/null 2>&1 && break; sleep 1; done
mariadb -e "CREATE USER IF NOT EXISTS '$U'@'localhost' IDENTIFIED VIA unix_socket; GRANT ALL PRIVILEGES ON *.* TO '$U'@'localhost' WITH GRANT OPTION; FLUSH PRIVILEGES;"
