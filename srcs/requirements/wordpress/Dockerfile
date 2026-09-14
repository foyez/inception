FROM alpine:3.23

RUN apk update && apk add --no-cache \
  php83 \
  php83-fpm \
  php83-mysqli \
  php83-phar \
  php83-mbstring \
  php83-tokenizer \
  mariadb-client \
  curl \
  bash

# Download WP-CLI
RUN curl -o /usr/local/bin/wp \
  https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
  chmod +x /usr/local/bin/wp && \
  apk del curl

# Create a symlink so `php` and `php-fpm` work without version suffix
RUN ln -sf /usr/bin/php83 /usr/bin/php && \
  ln -sf /usr/sbin/php-fpm83 /usr/sbin/php-fpm

COPY conf/php.ini /etc/php83/conf.d/custom.ini
COPY conf/www.conf /etc/php83/php-fpm.d/www.conf
COPY tools/entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

EXPOSE 9000

ENTRYPOINT [ "/entrypoint.sh" ]