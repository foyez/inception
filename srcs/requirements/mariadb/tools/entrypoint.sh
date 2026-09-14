#!/bin/sh

set -e

DB_ROOT_PASSWORD=$(cat /run/secrets/db_root_password | tr -d '\n')
DB_PASSWORD=$(cat /run/secrets/db_password | tr -d '\n')

mkdir -p /run/mysqld
chown -R mysql:mysql /run/mysqld
chown -R mysql:mysql /var/lib/mysql

# Initialize database only if it's empty
if [ ! -d "/var/lib/mysql/mysql" ]; then

  mariadb-install-db --user=mysql --datadir=/var/lib/mysql > /dev/null

  # start temporary server without networking for initialization
  # mariadbd --user=mysql --skip-networking --skip-grant-tables &
  mariadbd --user=mysql --skip-networking &
  MYSQL_PID=$!

  # wait until ready
  until mariadb-admin --socket=/run/mysqld/mysqld.sock ping --silent; do
    sleep 1
  done

  # run initial SQL setup
  mariadb --socket=/run/mysqld/mysqld.sock <<-EOSQL
    DELETE FROM mysql.user WHERE User='';
    DROP DATABASE IF EXISTS test;
    CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE};
    CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
    GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'%';
    ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
    FLUSH PRIVILEGES;
EOSQL

  # Stop the temporary mysqld
  kill "$MYSQL_PID"
  wait "$MYSQL_PID"
fi

# start real server (PID 1)
# exec mariadbd --user=mysql
exec mariadbd --user=mysql --skip-networking=0