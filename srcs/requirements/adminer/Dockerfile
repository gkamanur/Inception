FROM alpine:3.19

RUN apk update && apk upgrade && apk add --no-cache \
    php83 \
    php83-session \
    php83-mysqli \
    php83-pdo \
    php83-pdo_mysql \
    wget

# Create the web root directory
RUN mkdir -p /var/www/html

# Download Adminer to the web root
RUN wget https://github.com/vrana/adminer/releases/download/v4.8.1/adminer-4.8.1.php -O /var/www/html/index.php

EXPOSE 8080

CMD ["php83", "-S", "0.0.0.0:8080", "-t", "/var/www/html"]