# Dockerfile for FTP container
FROM debian:bullseye-slim

# Install vsftpd and dependencies
RUN apt-get update && apt-get install -y \
    vsftpd \
    curl \
    procps \
    logrotate \
    && rm -rf /var/lib/apt/lists/*

# Copy the fixed setup script
COPY tools/setup.sh  /usr/local/bin/
RUN chmod +x /usr/local/bin/setup.sh

# Create necessary directories
RUN mkdir -p /var/run/vsftpd

# Expose ports
EXPOSE 20 21 40000-40005

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD /usr/local/bin/ftp-healthcheck.sh

# Run setup script
CMD ["/usr/local/bin/setup.sh"]