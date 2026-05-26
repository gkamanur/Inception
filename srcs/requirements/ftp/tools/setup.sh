#!/bin/bash

FTP_USER=${FTP_USER:-ftpuser}

# Read password from Docker secret (fall back to env var)
if [ -f /run/secrets/ftp_password ]; then
    FTP_PASSWORD=$(cat /run/secrets/ftp_password)
else
    FTP_PASSWORD=${FTP_PASS:-ftppass}
fi

echo "=== FTP Server Setup ==="
echo "User: $FTP_USER"

# Ensure required directories exist
mkdir -p /var/run/vsftpd/empty
chmod 755 /var/run/vsftpd/empty
chown root:root /var/run/vsftpd/empty
echo "✓ Created secure_chroot_dir"

# Create user if doesn't exist
if ! id "$FTP_USER" &>/dev/null; then
    useradd -m -d /home/$FTP_USER -s /bin/bash $FTP_USER
    echo "✓ User created"
else
    echo "✓ User already exists"
fi

# Set password
echo "$FTP_USER:$FTP_PASSWORD" | chpasswd
echo "✓ Password set"

# Verify password was set
if grep -q "^$FTP_USER:" /etc/shadow; then
    echo "✓ Password verified in shadow file"
else
    echo "⚠ Password not found in shadow file"
fi

# Create userlist files
touch /etc/vsftpd.userlist
touch /etc/vsftpd.user_list
chmod 644 /etc/vsftpd.userlist /etc/vsftpd.user_list

# Add user to both files
for file in /etc/vsftpd.userlist /etc/vsftpd.user_list; do
    if ! grep -q "^$FTP_USER$" "$file" 2>/dev/null; then
        echo $FTP_USER >> "$file"
        echo "✓ Added to $file"
    fi
done

# Create FTP directory structure
mkdir -p /home/$FTP_USER/ftp/files
echo "✓ Created directory structure"

# Set permissions
chown nobody:nogroup /home/$FTP_USER/ftp 2>/dev/null || true
chmod a-w /home/$FTP_USER/ftp
chown -R $FTP_USER:$FTP_USER /home/$FTP_USER/ftp/files
echo "✓ Permissions set"

# Configure vsftpd.conf
if ! grep -q "secure_chroot_dir=" /etc/vsftpd.conf; then
    echo "secure_chroot_dir=/var/run/vsftpd/empty" >> /etc/vsftpd.conf
fi

if ! grep -q "local_root=" /etc/vsftpd.conf; then
    echo "local_root=/home/${FTP_USER}/ftp" >> /etc/vsftpd.conf
fi

# Ensure correct userlist file path
sed -i 's|userlist_file=.*|userlist_file=/etc/vsftpd.userlist|' /etc/vsftpd.conf

echo "=== Starting vsftpd ==="
echo "Configuration summary:"
grep -E "secure_chroot_dir|local_root|userlist_file|listen" /etc/vsftpd.conf

# Create vsftpd configuration
cat > /etc/vsftpd.conf <<EOF
# Basic settings
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
dirmessage_enable=YES

# Security
chroot_local_user=YES
allow_writeable_chroot=YES
secure_chroot_dir=/var/run/vsftpd/empty
seccomp_sandbox=NO

# Passive mode
pasv_enable=YES
pasv_min_port=40000
pasv_max_port=40005

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
EOF

# Start vsftpd in foreground
exec /usr/sbin/vsftpd