# syntax=docker/dockerfile:1
FROM debian:12

WORKDIR /usr/src

RUN <<-EOF1
	set -eux
	apt-get update
	apt-get install -y --no-install-recommends \
		ca-certificates \
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
	test -d /usr/src/wordpress
	rm -rf latest-ja.zip

	wget -O /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
	chmod +x /usr/local/bin/wp

	apt-get clean
	rm -rf /var/lib/apt/lists/*
EOF1

COPY --chmod=755 setup.sh /tmp/setup.sh

COPY www.conf /etc/php/8.2/fpm/pool.d/www.conf

EXPOSE 9000

STOPSIGNAL SIGQUIT

ENTRYPOINT ["/tmp/setup.sh"]