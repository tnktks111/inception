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

wait_for_redis() {
    local attempt
    local reply

    echo "Waiting for Redis at ${redis_host}:6379..."

    for attempt in {1..30}; do
        if reply="$(redis-cli -h "$redis_host" ping 2>/dev/null)" \
            && [ "$reply" = "PONG" ]; then
            echo "Redis is ready."
            return 0
        fi

        sleep 2
    done

    echo "Error: Redis did not become ready" >&2
    return 1
}

file_env MYSQL_PASSWORD
file_env WP_ADMIN_PASSWORD
file_env WP_PASSWORD

for var_name in \
    DOMAIN_NAME \
    MYSQL_DATABASE \
    MYSQL_USER \
    MYSQL_PASSWORD \
    WP_TITLE \
    WP_ADMIN_USER \
    WP_ADMIN_PASSWORD \
    WP_ADMIN_EMAIL \
    WP_USER \
    WP_PASSWORD \
    WP_USER_EMAIL
do
    require_env "$var_name"
done

redis_host="${WP_REDIS_HOST:-redis}"

mkdir -p /var/www/html

if [ ! -f /var/www/html/wp-load.php ]; then
    echo "Copying WordPress files..."
    cp -r /usr/src/wordpress/. /var/www/html/
fi

chown -R www-data:www-data /var/www/html
cd /var/www/html

wait_for_redis

if [ ! -f wp-config.php ]; then
    echo "Creating wp-config.php..."

    wp config create \
        --allow-root \
        --dbname="${MYSQL_DATABASE}" \
        --dbuser="${MYSQL_USER}" \
        --dbpass="${MYSQL_PASSWORD}" \
        --dbhost="${WORDPRESS_DB_HOST:-mariadb}"
fi

if ! wp core is-installed --allow-root 2>/dev/null; then
    echo "Installing WordPress..."

    wp core install \
        --allow-root \
        --url="https://${DOMAIN_NAME}" \
        --title="${WP_TITLE}" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PASSWORD}" \
        --admin_email="${WP_ADMIN_EMAIL}"
fi

if ! wp user get "${WP_USER}" --allow-root >/dev/null 2>&1; then
    echo "Creating WordPress user..."

    wp user create \
        --allow-root \
        "${WP_USER}" \
        "${WP_USER_EMAIL}" \
        --user_pass="${WP_PASSWORD}" \
        --role=author
fi

wp config set \
    WP_REDIS_HOST \
    "$redis_host" \
    --allow-root

if ! wp plugin is-installed redis-cache --allow-root; then
    wp plugin install redis-cache --allow-root
fi

if ! wp plugin is-active redis-cache --allow-root; then
    wp plugin activate redis-cache --allow-root
fi

if [ ! -f wp-content/object-cache.php ]; then
    wp redis enable --allow-root
fi

chown -R www-data:www-data /var/www/html

unset MYSQL_PASSWORD WP_ADMIN_PASSWORD WP_PASSWORD

echo "WordPress setup done!"

mkdir -p /run/php
chown www-data:www-data /run/php

exec /usr/sbin/php-fpm8.2 -F
