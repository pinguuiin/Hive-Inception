FROM alpine:3.21

RUN apk update && \
    apk add --no-cache \
    mariadb \
    mariadb-client

COPY conf/my.cnf /etc/my.cnf
COPY tools/setup.sh /setup.sh

RUN chmod +x /setup.sh

# Documents the port number the container listens on
EXPOSE 3306

CMD ["/setup.sh"]

