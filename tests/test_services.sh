#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
PASS=0
FAIL=0

run_test() {
    local name="$1"
    local result="$2"
    if [ "$result" -eq 0 ]; then
        echo -e "  [${GREEN}PASS${NC}] $name"
        ((PASS++))
    else
        echo -e "  [${RED}FAIL${NC}] $name"
        ((FAIL++))
    fi
}

echo "=============================="
echo "  FTP Tests"
echo "=============================="

# Test 1: FTP connection
curl -s --max-time 5 ftp://ftp_user:ftp_pass@localhost/ > /dev/null 2>&1
run_test "FTP login" $?

# Test 2: Upload a file via FTP
echo "inception test file" > /tmp/ftp_testfile.txt
curl -s --max-time 5 -T /tmp/ftp_testfile.txt ftp://ftp_user:ftp_pass@localhost/ftp_testfile.txt > /dev/null 2>&1
run_test "FTP upload file" $?

# Test 3: Download the uploaded file
curl -s --max-time 5 ftp://ftp_user:ftp_pass@localhost/ftp_testfile.txt -o /tmp/ftp_downloaded.txt > /dev/null 2>&1
run_test "FTP download file" $?

# Test 4: Verify file content matches
if [ -f /tmp/ftp_downloaded.txt ] && diff -q /tmp/ftp_testfile.txt /tmp/ftp_downloaded.txt > /dev/null 2>&1; then
    run_test "FTP file integrity" 0
else
    run_test "FTP file integrity" 1
fi

# Test 5: Reject bad credentials
curl -s --max-time 5 ftp://ftp_user:wrongpass@localhost/ > /dev/null 2>&1
if [ $? -ne 0 ]; then
    run_test "FTP reject bad password" 0
else
    run_test "FTP reject bad password" 1
fi

# Cleanup
rm -f /tmp/ftp_testfile.txt /tmp/ftp_downloaded.txt

echo ""
echo "=============================="
echo "  Redis Tests"
echo "=============================="

# Test 6: Redis PING
PONG=$(docker exec redis redis-cli -a redis_pass PING 2>/dev/null)
if [ "$PONG" = "PONG" ]; then
    run_test "Redis PING/PONG" 0
else
    run_test "Redis PING/PONG" 1
fi

# Test 7: Redis SET/GET
docker exec redis redis-cli -a redis_pass SET inception_test "hello42" > /dev/null 2>&1
VAL=$(docker exec redis redis-cli -a redis_pass GET inception_test 2>/dev/null)
if [ "$VAL" = "hello42" ]; then
    run_test "Redis SET/GET" 0
else
    run_test "Redis SET/GET" 1
fi

# Test 8: Redis DEL
docker exec redis redis-cli -a redis_pass DEL inception_test > /dev/null 2>&1
VAL=$(docker exec redis redis-cli -a redis_pass GET inception_test 2>/dev/null)
if [ -z "$VAL" ]; then
    run_test "Redis DEL key" 0
else
    run_test "Redis DEL key" 1
fi

# Test 9: Redis reject no password
RESULT=$(docker exec redis redis-cli PING 2>&1)
if echo "$RESULT" | grep -qi "NOAUTH\|ERR"; then
    run_test "Redis reject unauthenticated" 0
else
    run_test "Redis reject unauthenticated" 1
fi

# Test 10: WordPress Redis integration (object cache active)
WP_REDIS=$(docker exec wordpress wp --path=/var/www/html/wordpress redis status --allow-root 2>/dev/null)
if echo "$WP_REDIS" | grep -qi "connected\|enabled"; then
    run_test "WordPress Redis connected" 0
else
    run_test "WordPress Redis connected" 1
fi

echo ""
echo "=============================="
echo -e "  Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}"
echo "=============================="
exit $FAIL
