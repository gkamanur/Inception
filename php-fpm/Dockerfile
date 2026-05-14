FROM debian:bullseye

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Update and install required system packages
RUN apt-get update && apt-get install -y \
    lsb-release \
    apt-transport-https \
    ca-certificates \
    curl \
    wget \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

# Add PHP repository from SURY (maintained PHP packages for Debian)
RUN wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
RUN echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php.list

# Update package lists and install PHP
RUN apt-get update && apt-get install -y \
    php8.3 \
    php8.3-fpm \
    php8.3-cli \
    php8.3-common \
    php8.3-mysql \
    php8.3-pdo \
    php8.3-gd \
    php8.3-mbstring \
    php8.3-xml \
    php8.3-curl \
    php8.3-zip \
    && rm -rf /var/lib/apt/lists/*

# Create necessary directories
RUN mkdir -p /var/run/php && \
    chown -R www-data:www-data /var/run/php

# Copy custom PHP-FPM configuration (if needed)
# COPY php-fpm.conf /etc/php/8.3/fpm/php-fpm.conf
# COPY www.conf /etc/php/8.3/fpm/pool.d/www.conf

# Expose PHP-FPM port (not MySQL port 3306)
EXPOSE 9000

# Set working directory
WORKDIR /var/www/html

# Start PHP-FPM
ENTRYPOINT ["php-fpm8.3", "-F"]