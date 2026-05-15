FROM debian:bullseye-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    lsb-release curl wget gnupg ca-certificates vim mariadb-client \
    && wget -qO /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg \
    && echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list \
    && apt-get update && apt-get install -y --no-install-recommends \
        php8.3-fpm \
        php8.3-mysql \
        php8.3-cli \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /run/php /var/www/html \
    && chown -R www-data:www-data /run/php /var/www/html

COPY ./mytheme /theme/mytheme

COPY tools/setup.sh /bin/setup.sh
RUN chmod +x /bin/setup.sh

RUN sed -i 's|^listen = .*|listen = 9000|' \
    /etc/php/8.3/fpm/pool.d/www.conf

# Create socket directory
RUN mkdir -p /run/php && \
    chown -R www-data:www-data /run/php

RUN chown -R www-data:www-data /var/www/html


WORKDIR /var/www/html

EXPOSE 9000

CMD ["setup.sh"]