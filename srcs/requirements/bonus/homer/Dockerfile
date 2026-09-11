FROM debian:12

WORKDIR /var/www/html/homer

RUN <<-EOF
	set -eu
	apt-get update
	apt-get install -y --no-install-recommends \
	ca-certificates \
	wget \
	unzip \
	lighttpd
	apt-get clean
	rm -rf /var/lib/apt/lists/*

	wget -qO homer.zip https://github.com/bastienwirtz/homer/releases/latest/download/homer.zip
	unzip homer.zip
	rm homer.zip
	chown -R www-data:www-data /var/www/html
EOF

COPY config.yml /var/www/html/homer/assets/config.yml

CMD ["lighttpd", "-D", "-f", "/etc/lighttpd/lighttpd.conf"]

EXPOSE 80
