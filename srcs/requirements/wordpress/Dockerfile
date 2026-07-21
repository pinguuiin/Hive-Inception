FROM alpine:3.23

RUN apk update && \
    apk add --no-cache \
    php84 \
    php84-fpm \
    php84-mysqli \
    php84-mbstring \
    php84-iconv \
    php84-phar \
    mariadb-client \
    curl

# Increase PHP's memory limit to avoid memory exhaustion errors
RUN echo "memory_limit = 512M" > /etc/php84/conf.d/99-memory-limit.ini

# Install WP-CLI and move it to system PATH to make it executable by just typing `wp`
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp

# Create runtime directory
RUN mkdir -p /run/php

# WordPress file directory
WORKDIR /var/www/html

# Override the default PHP-FPM configuration file
COPY conf/www.conf /etc/php84/php-fpm.d/www.conf

COPY tools/setup.sh /usr/local/bin/setup.sh
RUN chmod +x /usr/local/bin/setup.sh

# Documents the port number PHP-FPM listens on
EXPOSE 9000

CMD ["/usr/local/bin/setup.sh"]
