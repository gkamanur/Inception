#!/bin/bash
set -e

# ── Read passwords from Docker secrets (fall back to env vars) ──
[ -f /run/secrets/db_password ]    && MYSQL_PASSWORD=$(cat /run/secrets/db_password)
[ -f /run/secrets/credentials ]    && WP_ADMIN_PASSWORD=$(cat /run/secrets/credentials)
[ -f /run/secrets/redis_password ] && REDIS_PASSWORD=$(cat /run/secrets/redis_password)
[ -f /run/secrets/ftp_password ]   && FTP_PASS=$(cat /run/secrets/ftp_password)

# Non-admin user password: derived from admin password with a suffix
WP_USER_PASSWORD="${WP_ADMIN_PASSWORD}_user"

WPDIR="/var/www/html/wordpress"
mkdir -p $WPDIR
cd $WPDIR

# ============================================
# NEW: Install Redis PHP Extension (CRITICAL!)
# ============================================
install_redis_extension() {
    echo "=== Installing Redis PHP Extension ==="
    
    # Detect PHP version
    PHP_VERSION=$(php -v | head -1 | cut -d' ' -f2 | cut -d'.' -f1,2)
    echo "Detected PHP version: $PHP_VERSION"
    
    # Check if Redis extension is already loaded
    if php -m | grep -q redis; then
        echo "✅ Redis extension already loaded"
        return 0
    fi
    
    # Install Redis extension based on package manager
    if command -v apt-get >/dev/null 2>&1; then
        echo "Using apt-get to install Redis extension..."
        apt-get update -qq
        
        # Try to install matching PHP version
        if apt-cache show php${PHP_VERSION}-redis >/dev/null 2>&1; then
            apt-get install -y php${PHP_VERSION}-redis
        else
            # Add sury repository if needed
            apt-get install -y apt-transport-https lsb-release ca-certificates wget
            wget -q -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
            echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list
            apt-get update -qq
            apt-get install -y php${PHP_VERSION}-redis
        fi
        
    elif command -v apk >/dev/null 2>&1; then
        echo "Using apk to install Redis extension..."
        if [ "$PHP_VERSION" = "8.3" ]; then
            apk add --no-cache php83-redis
        elif [ "$PHP_VERSION" = "8.2" ]; then
            apk add --no-cache php82-redis
        else
            apk add --no-cache php-redis
        fi
    else
        echo "ERROR: No known package manager found"
        return 1
    fi
    
    # Enable the extension
    echo "Enabling Redis extension..."
    mkdir -p /etc/php/${PHP_VERSION}/cli/conf.d
    echo "extension=redis.so" > /etc/php/${PHP_VERSION}/cli/conf.d/20-redis.ini
    
    # Also enable for FPM if directory exists
    if [ -d /etc/php/${PHP_VERSION}/fpm/conf.d ]; then
        echo "extension=redis.so" > /etc/php/${PHP_VERSION}/fpm/conf.d/20-redis.ini
    fi
    
    # Verify extension is loaded
    if php -m | grep -q redis; then
        echo "✅ Redis extension installed and loaded successfully"
    else
        echo "❌ WARNING: Redis extension installed but not loaded"
        echo "Trying with full path..."
        
        # Find redis.so location
        REDIS_SO=$(find / -name "redis.so" 2>/dev/null | head -1)
        if [ -n "$REDIS_SO" ]; then
            echo "extension=${REDIS_SO}" > /etc/php/${PHP_VERSION}/cli/conf.d/20-redis.ini
            if php -m | grep -q redis; then
                echo "✅ Redis extension loaded with full path"
            fi
        fi
    fi
}

# ============================================
# NEW: Test Redis Connection
# ============================================
test_redis_connection() {
    echo "=== Testing Redis Connection ==="
    
    # Wait for Redis to be ready
    echo "Waiting for Redis to be ready..."
    for i in $(seq 1 30); do
        if php -r "
            try {
                \$r = new Redis();
                if (\$r->connect('redis', 6379)) {
                    echo 'Redis ready\n';
                    exit(0);
                }
            } catch (Exception \$e) {
                exit(1);
            }
        " 2>/dev/null; then
            echo "Redis is ready!"
            break
        fi
        if [ $i -eq 30 ]; then
            echo "WARNING: Redis not ready, but continuing..."
            return 0
        fi
        echo "Redis not ready yet... attempt $i/30"
        sleep 2
    done
    
    # Test Redis with password
    php -r "
        \$redis = new Redis();
        if (\$redis->connect('redis', 6379)) {
            if (\$redis->auth('$REDIS_PASSWORD')) {
                echo '✅ Redis connection successful\n';
                \$redis->set('test_key', 'test_value');
                \$value = \$redis->get('test_key');
                if (\$value === 'test_value') {
                    echo '✅ Redis write/read test passed\n';
                }
                \$redis->del('test_key');
            } else {
                echo '❌ Redis authentication failed\n';
            }
        } else {
            echo '❌ Redis connection failed\n';
        }
    "
}

# ============================================
# Install WP-CLI if missing
# ============================================
if ! command -v wp >/dev/null 2>&1; then
    curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    chmod +x wp-cli.phar
    mv wp-cli.phar /usr/local/bin/wp
fi

# ============================================
# Install Redis PHP Extension (CRITICAL FIX)
# ============================================
install_redis_extension

# Download WordPress only if missing
if [ ! -f wp-load.php ]; then
    wp core download --allow-root
fi

# Wait for MariaDB to be ready
echo "Waiting for MariaDB..."
for i in $(seq 1 30); do
    if mysql -h mariadb -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" -e "SELECT 1;" >/dev/null 2>&1; then
        echo "MariaDB is ready!"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "ERROR: MariaDB did not become ready in time."
        exit 1
    fi
    echo "MariaDB not ready yet... attempt $i/30"
    sleep 2
done

# Ensure themes directory exists
mkdir -p $WPDIR/wp-content/themes

# Always sync theme files (overwrite with latest from image)
cp -rf /theme/mytheme $WPDIR/wp-content/themes/

# Create config only if missing
if [ ! -f wp-config.php ]; then
    wp config create --allow-root \
        --dbname="$MYSQL_DATABASE" \
        --dbuser="$MYSQL_USER" \
        --dbpass="$MYSQL_PASSWORD" \
        --dbhost="mariadb"
        
    wp config shuffle-salts --allow-root

    # Redis configuration
    wp config set WP_REDIS_HOST 'redis' --allow-root
    wp config set WP_REDIS_PORT 6379 --raw --allow-root
    wp config set WP_REDIS_PASSWORD "$REDIS_PASSWORD" --allow-root
    wp config set WP_CACHE true --raw --allow-root

    # FTP Configuration for WordPress updates
    wp config set FS_METHOD 'ftpext' --allow-root
    wp config set FTP_HOST 'ftp:21' --allow-root
    wp config set FTP_USER "$FTP_USER" --allow-root
    wp config set FTP_PASS "$FTP_PASS" --allow-root
    wp config set FTP_SSL false --raw --allow-root
fi

# Install only if not installed
if ! wp core is-installed --allow-root; then
    wp core install --allow-root \
        --url="$WP_URL" \
        --title="$WP_TITLE" \
        --admin_user="$WP_ADMIN_USER" \
        --admin_password="$WP_ADMIN_PASSWORD" \
        --admin_email="$WP_ADMIN_EMAIL"

    wp user create --allow-root \
        "$WP_USER" "$WP_USER_EMAIL" \
        --user_pass="$WP_USER_PASSWORD" \
        --role=author
    
    wp theme activate mytheme --allow-root

    # Install and activate Redis Cache plugin
    wp plugin install redis-cache --activate --allow-root

    # Enable Redis object cache
    wp redis enable --allow-root
    
    # ============================================
    # NEW: Verify Redis cache is working
    # ============================================
    echo "=== Verifying Redis Cache ==="
    wp redis status --allow-root
    
    # Test Redis cache
    wp cache set test_key test_value --allow-root
    CACHE_TEST=$(wp cache get test_key --allow-root)
    if [ "$CACHE_TEST" = "test_value" ]; then
        echo "✅ WordPress Redis cache is working!"
    else
        echo "⚠️  WordPress Redis cache test failed"
    fi

    # Set proper file permissions for FTP
    chown -R www-data:www-data $WPDIR
    chmod -R 755 $WPDIR
fi

# ============================================
# NEW: Test Redis connection (even if already installed)
# ============================================
test_redis_connection

# Define FTP constants for WordPress (alternative method)
if ! grep -q "FTP_HOST" wp-config.php; then
    cat >> wp-config.php <<EOF

// FTP Settings for automatic updates
define('FS_METHOD', 'ftpext');
define('FTP_HOST', 'ftp:21');
define('FTP_USER', '${FTP_USER}');
define('FTP_PASS', '${FTP_PASS}');
define('FTP_SSL', false);
EOF
fi

# ============================================
# NEW: Restart PHP-FPM to ensure Redis extension loads
# ============================================
echo "Restarting PHP-FPM to apply changes..."
kill -USR2 1 2>/dev/null || service php8.3-fpm restart 2>/dev/null || true

exec php-fpm8.3 -F