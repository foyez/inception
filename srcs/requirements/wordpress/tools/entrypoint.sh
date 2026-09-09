#!/bin/bash

set -e
# set -x  # print every command as it runs ← add this during debugging

DB_PASSWORD=$(cat /run/secrets/db_password | tr -d '\n')
WP_ADMIN_PASSWORD=$(cat /run/secrets/wp_admin_password | tr -d '\n')
WP_USER_PASSWORD=$(cat /run/secrets/wp_user_password | tr -d '\n')

echo "Waiting for MariaDB..."
until mariadb-admin ping -h mariadb -u "${MYSQL_USER}" -p"${DB_PASSWORD}" --silent; do
    sleep 2
done
echo "MariaDB is up."

# Create webroot directory and move there
mkdir -p /var/www/html
cd /var/www/html

# Ensure WordPress core files exist locally
if [ ! -f /var/www/html/wp-load.php ]; then
  wp core download --allow-root --quiet
fi

# Ensure wp-config.php exists
if [ ! -f /var/www/html/wp-config.php ]; then
  wp config create \
    --allow-root \
    --dbname="${MYSQL_DATABASE}" \
    --dbuser="${MYSQL_USER}" \
    --dbpass="${DB_PASSWORD}" \
    --dbhost="mariadb" \
    --quiet
fi

# Install WordPress only once per database
if ! wp core is-installed --allow-root >/dev/null 2>&1; then
  wp core install \
    --allow-root \
    --url="https://${DOMAIN_NAME}" \
    --title="${WP_TITLE}" \
    --admin_user="${WP_ADMIN_USER}" \
    --admin_password="${WP_ADMIN_PASSWORD}" \
    --admin_email="${WP_ADMIN_EMAIL}" \
    --skip-email \
    --quiet
fi

# Create secondary user only if it does not exist yet
if ! wp user get "${WP_USER}" --field=ID --allow-root >/dev/null 2>&1; then
  wp user create \
    --allow-root \
    "${WP_USER}" "${WP_USER_EMAIL}" \
    --role=author \
    --user_pass="${WP_USER_PASSWORD}" \
    --quiet
fi

chown -R nobody:nobody /var/www/html

php-fpm -t

exec php-fpm -F