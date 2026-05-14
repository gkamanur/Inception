#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================="
echo "Testing Inception Services Individually"
echo "========================================="

# Clean up previous tests
echo -e "${YELLOW}Cleaning up previous test containers...${NC}"
docker stop test-mariadb test-wordpress test-nginx 2>/dev/null
docker rm test-mariadb test-wordpress test-nginx 2>/dev/null
docker volume rm mariadb_test_volume wordpress_test_volume 2>/dev/null

# Create test volumes
docker volume create mariadb_test_volume
docker volume create wordpress_test_volume

# ==========================================
# TEST 1: MariaDB
# ==========================================
echo -e "\n${YELLOW}[TEST 1] Testing MariaDB...${NC}"

# Build MariaDB
echo "Building MariaDB image..."
docker build -t test-mariadb ./srcs/requirements/mariadb

# Run MariaDB
docker run -d --name test-mariadb \
  -e MYSQL_ROOT_PASSWORD=RootPass123 \
  -e MYSQL_DATABASE=wordpress \
  -e MYSQL_USER=wp_user \
  -e MYSQL_PASSWORD=UserPass123 \
  -v mariadb_test_volume:/var/lib/mysql \
  test-mariadb

sleep 5

# Test 1.1: Container running
if docker ps | grep -q test-mariadb; then
    echo -e "${GREEN}✓ MariaDB container is running${NC}"
else
    echo -e "${RED}✗ MariaDB container failed to start${NC}"
    docker logs test-mariadb
    exit 1
fi

# Test 1.2: Database accessible
if docker exec test-mariadb mysqladmin -u root -pRootPass123 status &>/dev/null; then
    echo -e "${GREEN}✓ MariaDB is accepting connections${NC}"
else
    echo -e "${RED}✗ MariaDB connection failed${NC}"
fi

# Test 1.3: Database created
if docker exec test-mariadb mysql -u root -pRootPass123 -e "SHOW DATABASES;" | grep -q wordpress; then
    echo -e "${GREEN}✓ WordPress database created${NC}"
else
    echo -e "${RED}✗ WordPress database not found${NC}"
fi

# Test 1.4: User created
if docker exec test-mariadb mysql -u root -pRootPass123 -e "SELECT User FROM mysql.user;" | grep -q wp_user; then
    echo -e "${GREEN}✓ WordPress user created${NC}"
else
    echo -e "${RED}✗ WordPress user not found${NC}"
fi

# Test 1.5: Volume persistence
docker stop test-mariadb
docker start test-mariadb
sleep 3
if docker exec test-mariadb mysqladmin -u root -pRootPass123 status &>/dev/null; then
    echo -e "${GREEN}✓ Data persists after restart${NC}"
else
    echo -e "${RED}✗ Data persistence failed${NC}"
fi

# ==========================================
# TEST 2: WordPress
# ==========================================
echo -e "\n${YELLOW}[TEST 2] Testing WordPress...${NC}"

# Build WordPress
echo "Building WordPress image..."
docker build -t test-wordpress ./srcs/requirements/wordpress

# Run WordPress
docker run -d --name test-wordpress \
  --link test-mariadb:mariadb \
  -e MYSQL_DATABASE=wordpress \
  -e MYSQL_USER=wp_user \
  -e MYSQL_PASSWORD=UserPass123 \
  -v wordpress_test_volume:/var/www/html \
  test-wordpress

sleep 5

# Test 2.1: Container running
if docker ps | grep -q test-wordpress; then
    echo -e "${GREEN}✓ WordPress container is running${NC}"
else
    echo -e "${RED}✗ WordPress container failed to start${NC}"
    docker logs test-wordpress
fi

# Test 2.2: PHP-FPM running
if docker exec test-wordpress ps aux | grep -q php-fpm; then
    echo -e "${GREEN}✓ PHP-FPM is running${NC}"
else
    echo -e "${RED}✗ PHP-FPM not running${NC}"
fi

# Test 2.3: WordPress files copied
if docker exec test-wordpress ls /var/www/html/wp-config.php &>/dev/null; then
    echo -e "${GREEN}✓ WordPress files copied successfully${NC}"
else
    echo -e "${RED}✗ WordPress files not copied${NC}"
fi

# Test 2.4: Database connection from WordPress
if docker exec test-wordpress php -r "
try {
    \$pdo = new PDO('mysql:host=mariadb;dbname=wordpress', 'wp_user', 'UserPass123');
    exit(0);
} catch(Exception \$e) {
    exit(1);
}
" &>/dev/null; then
    echo -e "${GREEN}✓ WordPress can connect to database${NC}"
else
    echo -e "${RED}✗ WordPress cannot connect to database${NC}"
fi

# Test 2.5: PHP-FPM port exposed
if docker exec test-wordpress netstat -tuln | grep -q ":9000"; then
    echo -e "${GREEN}✓ PHP-FPM listening on port 9000${NC}"
else
    echo -e "${RED}✗ PHP-FPM port 9000 not listening${NC}"
fi

# ==========================================
# TEST 3: NGINX
# ==========================================
echo -e "\n${YELLOW}[TEST 3] Testing NGINX...${NC}"

# Build NGINX
echo "Building NGINX image..."
docker build -t test-nginx ./srcs/requirements/nginx

# Run NGINX
docker run -d --name test-nginx \
  -p 4443:443 \
  --link test-wordpress:wordpress \
  -v wordpress_test_volume:/var/www/html \
  -e DOMAIN_NAME=localhost \
  test-nginx

sleep 3

# Test 3.1: Container running
if docker ps | grep -q test-nginx; then
    echo -e "${GREEN}✓ NGINX container is running${NC}"
else
    echo -e "${RED}✗ NGINX container failed to start${NC}"
    docker logs test-nginx
fi

# Test 3.2: SSL certificate exists
if docker exec test-nginx ls /etc/nginx/ssl/inception.crt &>/dev/null; then
    echo -e "${GREEN}✓ SSL certificate created${NC}"
else
    echo -e "${RED}✗ SSL certificate missing${NC}"
fi

# Test 3.3: TLS protocols (should be TLSv1.2/1.3 only)
if docker exec test-nginx nginx -T 2>&1 | grep -q "ssl_protocols TLSv1.2 TLSv1.3"; then
    echo -e "${GREEN}✓ TLSv1.2/1.3 configured${NC}"
else
    echo -e "${RED}✗ TLS configuration incorrect${NC}"
fi

# Test 3.4: Port 443 listening
if docker exec test-nginx netstat -tuln | grep -q ":443"; then
    echo -e "${GREEN}✓ Port 443 is listening${NC}"
else
    echo -e "${RED}✗ Port 443 not listening${NC}"
fi

# Test 3.5: HTTPS accessible from host
if curl -k -s -o /dev/null -w "%{http_code}" https://localhost:4443 | grep -q "200\|301\|302"; then
    echo -e "${GREEN}✓ HTTPS endpoint is accessible${NC}"
else
    echo -e "${RED}✗ HTTPS endpoint not accessible${NC}"
fi

# ==========================================
# TEST 4: Integration
# ==========================================
echo -e "\n${YELLOW}[TEST 4] Testing Integration...${NC}"

# Test 4.1: NGINX can reach WordPress
if docker exec test-nginx wget -q -O- http://wordpress:9000 &>/dev/null; then
    echo -e "${GREEN}✓ NGINX can reach WordPress (port 9000)${NC}"
else
    echo -e "${RED}✗ NGINX cannot reach WordPress${NC}"
fi

# Test 4.2: End-to-end WordPress access via NGINX
HTTP_CODE=$(docker exec test-nginx curl -k -s -o /dev/null -w "%{http_code}" https://localhost 2>/dev/null)
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ]; then
    echo -e "${GREEN}✓ WordPress accessible via NGINX (HTTP $HTTP_CODE)${NC}"
else
    echo -e "${RED}✗ WordPress not accessible via NGINX (HTTP $HTTP_CODE)${NC}"
fi

# ==========================================
# SUMMARY
# ==========================================
echo -e "\n${YELLOW}=========================================${NC}"
echo -e "${GREEN}Testing Complete!${NC}"
echo -e "${YELLOW}=========================================${NC}"

echo -e "\nTo check logs of individual containers:"
echo "  docker logs test-mariadb"
echo "  docker logs test-wordpress"
echo "  docker logs test-nginx"

echo -e "\nTo clean up:"
echo "  docker stop test-mariadb test-wordpress test-nginx"
echo "  docker rm test-mariadb test-wordpress test-nginx"
echo "  docker volume rm mariadb_test_volume wordpress_test_volume"

# Keep containers running for manual inspection
echo -e "\n${GREEN}Containers are still running for manual inspection${NC}"
echo "Press Enter to clean up containers..."
read

# Cleanup
docker stop test-mariadb test-wordpress test-nginx
docker rm test-mariadb test-wordpress test-nginx
docker volume rm mariadb_test_volume wordpress_test_volume

echo -e "${GREEN}Cleanup complete!${NC}"