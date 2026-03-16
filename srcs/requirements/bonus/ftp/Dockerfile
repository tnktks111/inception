FROM debian:12

RUN <<-EOF
	apt-get update
	apt-get install -y --no-install-recommends vsftpd
	apt-get clean
	rm -rf /var/lib/apt/lists/*
EOF

RUN mkdir -p /var/run/vsftpd/empty

COPY vsftpd.conf /etc/vsftpd.conf.template
COPY --chmod=755 docker-entrypoint.sh /tmp/docker-entrypoint.sh

EXPOSE 21 21100-21110

ENTRYPOINT ["/tmp/docker-entrypoint.sh"]
