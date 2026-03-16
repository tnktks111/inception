# syntax=docker/dockerfile:1
FROM debian:12

WORKDIR /var/www/html

ARG ADMINER_VERSION=5.4.2
RUN <<-EOF
	set -eux
	apt-get update
	apt-get install -y --no-install-recommends \
		wget \
		ca-certificates \
		php8.2 \
		php8.2-cli \
		php8.2-mysql
	apt-get clean
	rm -rf /var/lib/apt/lists/*

	groupadd -r adminer && useradd -r -g adminer adminer
	mkdir -p /var/www/html
	chown -R adminer:adminer /var/www/html

	wget -O index.php https://github.com/vrana/adminer/releases/download/v${ADMINER_VERSION}/adminer-${ADMINER_VERSION}.php
	chown adminer:adminer index.php
EOF

USER adminer
CMD ["php", "-S", "0.0.0.0:8080", "-t", "/var/www/html"]
EXPOSE 8080