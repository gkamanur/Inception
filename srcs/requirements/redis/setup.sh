#!/bin/sh

# Add requirepass if REDIS_PASSWORD is set
if [ -n "$REDIS_PASSWORD" ]; then
    echo "requirepass $REDIS_PASSWORD" >> /etc/redis.conf
fi

# Start redis-server
exec redis-server /etc/redis.conf