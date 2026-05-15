#!/bin/bash

set -e

DATADIR="/var/lib/mysql"

mysql_install_db --user=mysql --datadir=$DATADIR

mysqld_safe --datadir=$DATADIR &
sleep 5

mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;

DROP USER IF EXISTS '${MYSQL_USER}'@'%';
CREATE USER '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';

# Create dedicated adminer user
CREATE USER IF NOT EXISTS 'adminer'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
GRANT ALL PRIVILEGES ON *.* TO 'adminer'@'%' WITH GRANT OPTION;

ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';

FLUSH PRIVILEGES;
EOF

mysqladmin -u root -p${MYSQL_ROOT_PASSWORD} shutdown

exec mysqld_safe --datadir=$DATADIR