#!/bin/sh

# Read password from Docker secret (fall back to env var)
if [ -f /run/secrets/redis_password ]; then
    REDIS_PASSWORD=$(cat /run/secrets/redis_password)
fi

# Bind to all interfaces (so other containers can connect)
echo "bind 0.0.0.0" >> /etc/redis.conf
echo "protected-mode no" >> /etc/redis.conf

# Add requirepass if REDIS_PASSWORD is set
if [ -n "$REDIS_PASSWORD" ]; then
    echo "requirepass $REDIS_PASSWORD" >> /etc/redis.conf
fi

# Start redis-server
exec redis-server /etc/redis.conf
