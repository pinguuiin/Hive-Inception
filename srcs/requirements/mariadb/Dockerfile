FROM alpine:3.21

RUN apk update && \
    apk add --no-cache \
    mariadb \
    mariadb-client

COPY conf/my.cnf /etc/my.cnf
COPY tools/setup.sh /setup.sh

RUN chmod +x /setup.sh

# Mainly for documentation as the containers communicate over the internal network
EXPOSE 3306

CMD ["/setup.sh"]

