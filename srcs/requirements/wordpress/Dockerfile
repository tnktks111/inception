# syntax=docker/dockerfile:1
FROM debian:12

WORKDIR /usr/src

RUN <<EOF1
    apt-get update
    apt-get install -y --no-install-recommends \
        wget unzip \
        mariadb-client \
        php8.2-fpm \
        php8.2-cli \
        php8.2-common \
        php8.2-curl \
        php8.2-bz2 \
        php8.2-gd \
        php8.2-mbstring \
        php8.2-mysql \
        php8.2-opcache \
        php8.2-readline \
        php8.2-xml \
        php8.2-zip

    wget https://ja.wordpress.org/latest-ja.zip
    unzip "latest-ja.zip"
    rm -rf latest-ja.zip

    wget -O /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    chmod +x /usr/local/bin/wp

    apt-get clean
    rm -rf /var/lib/apt/lists/*
EOF1

COPY --chmod=755 <<EOF2 /tmp/setup.sh
    #!/bin/bash
    set -ex

    mkdir -p /var/www/html
    if [ ! -f "/var/www/html/wp-config.php" ]; then
        echo "Setting up WordPress..."
        cp -r /usr/src/wordpress/* /var/www/html/
        chown -R www-data:www-data /var/www/html

        while ! mariadb -h mariadb -u\${MYSQL_USER} -p\${MYSQL_PASSWORD} -e "SELECT 1;" >/dev/null 2>&1; do
            echo "Waiting for MariaDB to start..."
            sleep 2
        done

        wp config create --allow-root \
            --dbname=\${MYSQL_DATABASE} \
            --dbuser=\${MYSQL_USER} \
            --dbpass=\${MYSQL_PASSWORD} \
            --dbhost=mariadb \
            --path=/var/www/html

        wp core install --allow-root \
            --url=https://\${DOMAIN_NAME} \
            --title="\${WP_TITLE}" \
            --admin_user=\${WP_ADMIN_USER} \
            --admin_password=\${WP_ADMIN_PASSWORD} \
            --admin_email=\${WP_ADMIN_EMAIL} \
            --path=/var/www/html

        wp user create --allow-root \
            \${WP_USER} \
            \${WP_USER_EMAIL} \
            --user_pass=\${WP_PASSWORD} \
            --role=author \
            --path=/var/www/html

        chown -R www-data:www-data /var/www/html

        echo "WordPress setup done !"
    fi

    mkdir -p /run/php
    chown www-data:www-data /run/php

    exec /usr/sbin/php-fpm8.2 -F
EOF2

COPY <<EOF3 /etc/php/8.2/fpm/pool.d/www.conf
    [www]
    listen = 9000

    user = www-data
    group = www-data

    pm = dynamic
    pm.max_children = 5
    pm.start_servers = 2 
    pm.min_spare_servers = 1 
    pm.max_spare_servers = 3
    clear_env = no
EOF3

EXPOSE 9000

STOPSIGNAL SIGQUIT

ENTRYPOINT ["/tmp/setup.sh"]