FROM debian:bullseye

RUN apt-get update && apt-get install -y php7.4-fpm php7.4-mysqli wget curl mariadb-client

COPY conf/www.conf /etc/php/7.4/fpm/pool.d/www.conf
COPY tools/wp.sh /bin/wp.sh
RUN chmod +x /bin/wp.sh

RUN mkdir -p /run/php

EXPOSE 9000

CMD ["wp.sh"]