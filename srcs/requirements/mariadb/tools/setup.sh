#!/bin/bash
set -e

# ── Read passwords from Docker secrets (fall back to env vars) ──
if [ -f /run/secrets/db_password ]; then
    MYSQL_PASSWORD=$(cat /run/secrets/db_password)
fi
if [ -f /run/secrets/db_root_password ]; then
    MYSQL_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)
fi

DATADIR="/var/lib/mysql"

# Ensure socket directory exists
mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld

# Ensure mysql user owns the data directory
chown -R mysql:mysql $DATADIR

# Only initialize if the data directory is empty
if [ ! -d "$DATADIR/mysql" ]; then
    mysql_install_db --user=mysql --datadir=$DATADIR

    mysqld --user=mysql --datadir=$DATADIR --skip-networking &
    sleep 5

    mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;

CREATE USER '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';

CREATE USER 'adminer'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
GRANT ALL PRIVILEGES ON *.* TO 'adminer'@'%' WITH GRANT OPTION;

ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';

FLUSH PRIVILEGES;
EOF

    mysqladmin -u root -p"${MYSQL_ROOT_PASSWORD}" shutdown
fi

exec mysqld --user=mysql --datadir=$DATADIR --console
