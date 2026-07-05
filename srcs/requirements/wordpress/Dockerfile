FROM alpine:3.21

RUN apk update && \
    apk add --no-cache \
    php83 \
    php83-fpm \
    php83-mysqli \
    php83-phar \
    curl

# Install WP-CLI and make it executable by just typing `wp`
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp

# Create runtime directory
RUN mkdir -p /run/php

# Override the default PHP-FPM configuration file
COPY conf/www.conf /etc/php83/php-fpm.d/www.conf

COPY tools/setup.sh /setup.sh
RUN chmod +x /setup.sh

# PHP-FPM listens on port 9000, mainly for documentation as containers communicate over
# the internal network. This port is not published to the host.
EXPOSE 9000

CMD ["/setup.sh"]
