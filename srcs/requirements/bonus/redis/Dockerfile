# syntax=docker/dockerfile:1
FROM debian:12
RUN <<-EOF
	apt-get update
	apt-get install -y --no-install-recommends redis-server
	apt-get clean
	rm -rf /var/lib/apt/lists/*	

	sed -i "s|bind 127.0.0.1 -::1|bind 0.0.0.0|g" /etc/redis/redis.conf
	sed -i "s|protected-mode yes|protected-mode no|g" /etc/redis/redis.conf
	sed -i "s|^daemonize yes|daemonize no|g" /etc/redis/redis.conf
EOF

CMD ["redis-server", "/etc/redis/redis.conf"]

EXPOSE 6379
