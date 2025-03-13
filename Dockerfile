FROM docker:latest

RUN apk add --no-cache bash openssh-client

COPY docker-entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]