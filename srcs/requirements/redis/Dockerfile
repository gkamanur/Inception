FROM alpine:3.19

RUN apk update && apk upgrade && apk add --no-cache redis

RUN touch /etc/redis.conf && chown redis:redis /etc/redis.conf

USER redis
EXPOSE 6379

COPY --chown=redis:redis setup.sh /setup.sh
RUN chmod +x /setup.sh

CMD ["/setup.sh"]