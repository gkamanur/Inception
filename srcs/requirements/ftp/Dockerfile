FROM debian:bullseye-slim

# Install vsftpd and create required directories
RUN apt-get update && apt-get install -y \
    vsftpd \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/run/vsftpd/empty \
    && chmod 755 /var/run/vsftpd/empty \
    && chown root:root /var/run/vsftpd/empty

# Create empty userlist
RUN touch /etc/vsftpd.userlist && chmod 644 /etc/vsftpd.userlist

# Copy entrypoint script
COPY tools/setup.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 21 40000-40005

ENTRYPOINT ["/entrypoint.sh"]