#!/bin/bash

##############################################################################
# FTP Server Setup Script - MATCHES TEST EXPECTATIONS
# Test expects: /ftp/ directory for uploads (not /ftp/files/)
##############################################################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ============================================
# Configuration - MATCH TEST EXPECTATIONS
# ============================================
FTP_USER="ftp_user"  # Exact match from test
FTP_PASSWORD="ftp_pass"  # Exact match from test
FTP_HOME="/home/${FTP_USER}"
CHROOT_DIR="ftp"  # Test uploads to /ftp/
VSFTPD_CONFIG="/etc/vsftpd.conf"

log_info "=== FTP Server Setup (Test Compatible) ==="
log_info "User: $FTP_USER"
log_info "Upload path: /$CHROOT_DIR/ (matches test expectation)"

# ============================================
# 1. Create Required Directories
# ============================================
log_info "Creating required directories..."
mkdir -p /var/run/vsftpd/empty
chmod 755 /var/run/vsftpd/empty
chown root:root /var/run/vsftpd/empty

# ============================================
# 2. Create FTP User
# ============================================
if ! id "$FTP_USER" &>/dev/null; then
    useradd -m -d "$FTP_HOME" -s /bin/bash "$FTP_USER"
    log_info "✓ User created"
else
    log_info "✓ User already exists"
fi

# Set password
echo "$FTP_USER:$FTP_PASSWORD" | chpasswd
log_info "✓ Password set"

# ============================================
# 3. Create Directory Structure for TEST
# ============================================
# IMPORTANT: Test expects to upload to /ftp/ directly
# NOT to /ftp/files/ or any subdirectory
log_info "Creating directory structure..."

# Create the ftp directory that test expects
mkdir -p "$FTP_HOME/$CHROOT_DIR"
log_info "✓ Created: $FTP_HOME/$CHROOT_DIR"

# Set permissions for chroot
# Home directory owned by root for chroot
chown root:root "$FTP_HOME"
chmod 755 "$FTP_HOME"

# FTP directory and subdirectory owned by ftp_user
chown -R "$FTP_USER:$FTP_USER" "$FTP_HOME/$CHROOT_DIR"
chmod 755 "$FTP_HOME/$CHROOT_DIR"

log_info "✓ Permissions set"
log_info "Directory structure:"
ls -la "$FTP_HOME/"

# ============================================
# 4. Configure User Lists
# ============================================
log_info "Configuring user lists..."
echo "$FTP_USER" > /etc/vsftpd.userlist
echo "$FTP_USER" > /etc/vsftpd.user_list
chmod 644 /etc/vsftpd.userlist /etc/vsftpd.user_list

# ============================================
# 5. Configure vsftpd
# ============================================
log_info "Configuring vsftpd..."

# Write configuration
cat > "$VSFTPD_CONFIG" << EOF
# vsftpd configuration for Inception project
# Configured to match test expectations

# Basic settings
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
dirmessage_enable=YES

# Security - CRITICAL for chroot
chroot_local_user=YES
allow_writeable_chroot=YES
secure_chroot_dir=/var/run/vsftpd/empty
seccomp_sandbox=NO

# Local root - points to /ftp directory (where test uploads)
local_root=/home/ftp_user/ftp

# Passive mode (for Docker)
pasv_enable=YES
pasv_min_port=40000
pasv_max_port=40005
pasv_address=0.0.0.0

# User list
userlist_enable=YES
userlist_deny=NO
userlist_file=/etc/vsftpd.userlist

# Logging
xferlog_enable=YES
xferlog_file=/var/log/vsftpd.log
log_ftp_protocol=YES

# Connection
listen=YES
listen_ipv6=NO
connect_from_port_20=YES

# Performance
idle_session_timeout=600
data_connection_timeout=120

# File permissions
file_open_mode=0666
local_umask=022

# Banner
ftpd_banner=Welcome to Inception FTP service.
EOF

log_info "✓ vsftpd configuration written"
log_info "✓ local_root = /home/ftp_user/ftp (test uploads go here)"

# ============================================
# 6. Create Sample Test File
# ============================================
log_info "Creating sample test file..."

cat > "$FTP_HOME/$CHROOT_DIR/README.txt" << EOF
FTP Upload Directory

This directory is ready for file uploads.
The test script expects to upload files here.

Test upload path: /ftp/filename.txt
Actual path: $FTP_HOME/$CHROOT_DIR/

FTP User: $FTP_USER
Created on: $(date)
EOF

chown "$FTP_USER:$FTP_USER" "$FTP_HOME/$CHROOT_DIR/README.txt"
chmod 644 "$FTP_HOME/$CHROOT_DIR/README.txt"
log_info "✓ Sample README.txt created"

# ============================================
# 7. Create Test Script
# ============================================
log_info "Creating FTP test script..."

cat > /usr/local/bin/test-ftp.sh << 'TESTSCRIPT'
#!/bin/bash
# FTP Test Script for Inception - Matches main test

FTP_HOST="${FTP_HOST:-localhost}"
FTP_USER="ftp_user"
FTP_PASS="ftp_pass"
TEST_FILE="/tmp/ftp_test_$$.txt"

echo "Testing FTP connectivity..."

# Create test file
echo "FTP test from $(date)" > "$TEST_FILE"

# Test upload (matches test expectation)
echo -n "Upload test (/ftp/): "
if curl -s --max-time 10 -T "$TEST_FILE" \
    "ftp://${FTP_USER}:${FTP_PASS}@${FTP_HOST}/ftp/test_$$.txt" 2>/dev/null; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    rm -f "$TEST_FILE"
    exit 1
fi

# Test download
echo -n "Download test: "
if curl -s --max-time 10 \
    "ftp://${FTP_USER}:${FTP_PASS}@${FTP_HOST}/ftp/test_$$.txt" \
    -o "${TEST_FILE}.downloaded" 2>/dev/null; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    rm -f "$TEST_FILE"
    exit 1
fi

# Verify content
echo -n "Integrity test: "
if diff -q "$TEST_FILE" "${TEST_FILE}.downloaded" >/dev/null 2>&1; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    exit 1
fi

# Cleanup
curl -s --max-time 10 -Q "DELE /ftp/test_$$.txt" \
    "ftp://${FTP_USER}:${FTP_PASS}@${FTP_HOST}/" 2>/dev/null
rm -f "$TEST_FILE" "${TEST_FILE}.downloaded"

echo "✅ All FTP tests passed!"
exit 0
TESTSCRIPT

chmod +x /usr/local/bin/test-ftp.sh
log_info "✓ FTP test script created"

# ============================================
# 8. Verify Configuration
# ============================================
log_info "Verifying FTP configuration..."

# Test configuration syntax
if vsftpd -olisten=NO "$VSFTPD_CONFIG" 2>&1 | grep -q "500"; then
    log_error "❌ vsftpd configuration has errors"
    exit 1
else
    log_info "✅ vsftpd configuration syntax OK"
fi

# Check if upload directory is writable
if [ -w "$FTP_HOME/$CHROOT_DIR" ]; then
    log_info "✅ Upload directory is writable"
else
    log_error "⚠ Upload directory is NOT writable"
fi

# ============================================
# 9. Display Summary
# ============================================
echo ""
log_info "========================================="
log_info "FTP Configuration Complete!"
log_info "========================================="
echo ""
log_info "📁 Directory Structure:"
echo "   $FTP_HOME/"
echo "   └── $CHROOT_DIR/ (writable upload directory)"
echo "       └── README.txt"
echo ""
log_info "👤 FTP User: $FTP_USER"
log_info "🔑 Password: $FTP_PASSWORD"
log_info "📂 Upload Path: /$CHROOT_DIR/"
echo ""
log_info "✅ Test expects: ftp://${FTP_USER}:${FTP_PASSWORD}@localhost/${CHROOT_DIR}/"
echo ""
log_info "🧪 Test Commands:"
echo "   # Upload test"
echo "   echo 'test' > /tmp/test.txt"
echo "   curl -T /tmp/test.txt ftp://${FTP_USER}:${FTP_PASSWORD}@localhost/${CHROOT_DIR}/test.txt"
echo ""
echo "   # Download test"
echo "   curl ftp://${FTP_USER}:${FTP_PASSWORD}@localhost/${CHROOT_DIR}/test.txt"
echo ""
log_info "✅ Setup complete! Starting vsftpd..."

# ============================================
# 10. Start vsftpd
# ============================================
# Clean up any existing vsftpd processes
pkill vsftpd 2>/dev/null || true

# Start vsftpd in foreground
exec /usr/sbin/vsftpd "$VSFTPD_CONFIG"