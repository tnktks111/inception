FROM debian:12

WORKDIR /var/www/html

RUN <<-EOF
	apt-get update
	apt-get install -y --no-install-recommends \
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

COPY config.yml /var/www/html/assets/config.yml

CMD ["lighttpd", "-D", "-f", "/etc/lighttpd/lighttpd.conf"]

EXPOSE 80