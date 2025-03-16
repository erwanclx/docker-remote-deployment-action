# FROM docker:latest
FROM docker:23

RUN apk add --no-cache bash openssh-client

COPY docker-entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]