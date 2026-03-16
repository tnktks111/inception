#!/bin/bash
set -e

file_env() {
	local var_name="$1"
	local file_var_name="${var_name}_FILE"
	local value="${!var_name:-}"

	if [ -n "$value" ] && [ -n "${!file_var_name:-}" ]; then
		echo "Error: both $var_name and $file_var_name are set" >&2
		exit 1
	fi

	if [ -n "${!file_var_name:-}" ]; then
		value="$(< "${!file_var_name}")"
	fi

	export "$var_name=$value"
	unset "$file_var_name"
}

require_env() {
	local var_name="$1"
	if [ -z "${!var_name:-}" ]; then
		echo "Error: required environment variable '$var_name' is not set" >&2
		exit 1
	fi
}

mkdir -p /var/www/html
if [ ! -f "/var/www/html/wp-config.php" ]; then
	file_env MYSQL_PASSWORD
	file_env WP_ADMIN_PASSWORD
	file_env WP_PASSWORD

	require_env DOMAIN_NAME
	require_env MYSQL_DATABASE
	require_env MYSQL_USER
	require_env MYSQL_PASSWORD
	require_env WP_TITLE
	require_env WP_ADMIN_USER
	require_env WP_ADMIN_PASSWORD
	require_env WP_ADMIN_EMAIL
	require_env WP_USER
	require_env WP_PASSWORD
	require_env WP_USER_EMAIL

	echo "Setting up WordPress..."
	cp -r /usr/src/wordpress/. /var/www/html/
	chown -R www-data:www-data /var/www/html

	while ! MARIADB_PWD="${MYSQL_PASSWORD}" mariadb -h "${WORDPRESS_DB_HOST:-mariadb}" -u"${MYSQL_USER}" -e "SELECT 1;" >/dev/null 2>&1; do
		echo "Waiting for MariaDB to start..."
		sleep 2
	done

	cd /var/www/html

	wp config create --allow-root --dbname="${MYSQL_DATABASE}" --dbuser="${MYSQL_USER}" --dbpass="${MYSQL_PASSWORD}" --dbhost="${WORDPRESS_DB_HOST:-mariadb}"

	wp core install --allow-root --url="https://${DOMAIN_NAME}" --title="${WP_TITLE}" --admin_user="${WP_ADMIN_USER}" --admin_password="${WP_ADMIN_PASSWORD}" --admin_email="${WP_ADMIN_EMAIL}"

	wp user create --allow-root "${WP_USER}" "${WP_USER_EMAIL}" --user_pass="${WP_PASSWORD}" --role=author

	chown -R www-data:www-data /var/www/html

	echo "WordPress setup done !"
fi

mkdir -p /run/php
chown www-data:www-data /run/php

exec /usr/sbin/php-fpm8.2 -F
