#!/bin/bash
set -e

# Validate required environment variables
if [ -z "$MYSQL_DATABASE" ] || [ -z "$MYSQL_USER" ] || [ -z "$MYSQL_PASSWORD" ] || [ -z "$MYSQL_ROOT_PASSWORD" ]; then
    echo "ERROR: Missing required environment variables"
    exit 1
fi

echo "Using database: ${MYSQL_DATABASE}"
echo "Using user: ${MYSQL_USER}"

# Check if our specific wordpress database directory exists
if [ ! -d "/var/lib/mysql/${MYSQL_DATABASE}" ]; then
    echo "--- INITIALIZING DATABASE VIA BOOTSTRAP ---"

    # Create a temporary file containing all our initialization SQL
    TMP_FILE="/tmp/init.sql"
    
    cat << EOF > "$TMP_FILE"
-- Clear any default setup restrictions
FLUSH PRIVILEGES;

-- Create the database
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;

-- Create WordPress user for network (%) and localhost connections
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'localhost' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'localhost';

-- Change root authentication from unix_socket to password
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';

FLUSH PRIVILEGES;
EOF

    # Bootstrapping executes the SQL file directly into the system tables 
    # without starting the networking daemon, entirely bypassing socket issues.
    mysqld --user=mysql --bootstrap < "$TMP_FILE"
    rm -f "$TMP_FILE"
    echo "--- INITIALIZATION COMPLETE ---"
fi

echo "--- STARTING DAEMON IN FOREGROUND ---"
exec mysqld_safe --datadir=/var/lib/mysql