#!/bin/bash

set -e

DB_PASSWORD=$(cat /run/secrets/db_password | tr -d '\n')
WP_ADMIN_PASSWORD=$(cat /run/secrets/credentials | tr -d '\n')

echo "Waiting for MariaDB..."
until mariadb-admin ping -h mariadb -u "${MYSQL_USER}" -p"${DB_PASSWORD}" --silent; do
    sleep 2
done
echo "MariaDB is up."

if [ ! -f /var/www/html/wp-config.php ]; then

  # Create webroot directory
  mkdir -p /var/www/html
  cd /var/www/html

  # Download WordPress core files using WP-CLI
  wp core download --allow-root --quiet

  # Create wp-config.php
  wp config create \
    --allow-root \
    --dbname="${MYSQL_DATABASE}" \
    --dbuser="${MYSQL_USER}" \
    --dbpass="${DB_PASSWORD}" \
    --dbhost="mariadb" \
    --quiet

  # Install WordPress (creates DB tables, sets up admin account)
  wp core install \
    --allow-root \
    --url="https://${DOMAIN_NAME}" \
    --title="${WP_TITLE}" \
    --admin_user="${WP_ADMIN_USER}" \
    --admin_password="${WP_ADMIN_PASSWORD}" \
    --admin_email="${WP_ADMIN_EMAIL}" \
    --skip-email \
    --quiet

  # Create a second non-admin WordPress user
  wp user create \
    --allow-root \
    "${WP_USER}" "${WP_USER_EMAIL}" \
    --role=author \
    --user_pass="${WP_ADMIN_PASSWORD}" \
    --quiet

  chown -R nobody:nobody /var/www/html

fi

exec php-fpm -F