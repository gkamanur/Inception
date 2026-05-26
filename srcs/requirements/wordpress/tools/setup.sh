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

# Install WP-CLI if missing
if ! command -v wp >/dev/null 2>&1; then
    curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    chmod +x wp-cli.phar
    mv wp-cli.phar /usr/local/bin/wp
fi

# Download WordPress only if missing
if [ ! -f wp-load.php ]; then
    wp core download --allow-root
fi

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

    # Set proper file permissions for FTP
    chown -R www-data:www-data $WPDIR
    chmod -R 755 $WPDIR
fi

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

exec php-fpm8.3 -F