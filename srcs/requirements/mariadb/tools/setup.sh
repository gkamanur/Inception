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

# Initialize data directory if empty
if [ ! -d "$DATADIR/mysql" ]; then
    mysql_install_db --user=mysql --datadir=$DATADIR
fi

# Always start a temporary instance to ensure users are configured correctly.
# Use --skip-grant-tables so we can fix permissions even on existing data dirs.
mysqld --user=mysql --datadir=$DATADIR --skip-networking --skip-grant-tables &

# Wait for the temporary instance to be ready
for i in $(seq 1 30); do
    if mysqladmin ping --silent 2>/dev/null; then
        break
    fi
    sleep 1
done

mysql -u root <<EOF
FLUSH PRIVILEGES;

CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;

-- Ensure the WordPress user can connect from any host (other containers)
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
ALTER USER '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';

-- Ensure the adminer user can connect from any host
CREATE USER IF NOT EXISTS 'adminer'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
ALTER USER 'adminer'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
GRANT ALL PRIVILEGES ON *.* TO 'adminer'@'%' WITH GRANT OPTION;

ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';

FLUSH PRIVILEGES;
EOF

mysqladmin -u root -p"${MYSQL_ROOT_PASSWORD}" shutdown
wait

exec mysqld --user=mysql --datadir=$DATADIR --console
