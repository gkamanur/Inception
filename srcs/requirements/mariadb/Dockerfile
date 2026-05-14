FROM debian:bullseye

RUN apt-get update && apt-get install -y mariadb-server

COPY conf/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf
COPY tools/setup.sh /bin/setup.sh
RUN chmod +x /bin/setup.sh

EXPOSE 3306

CMD ["setup.sh"]