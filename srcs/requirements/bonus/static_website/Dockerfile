# syntax=docker/dockerfile:1
FROM debian:12

RUN <<-EOF
	apt-get update
	apt-get install -y --no-install-recommends python3
	apt-get clean
	rm -rf /var/lib/apt/lists/*
EOF

WORKDIR /var/www/html

COPY index.html .

CMD ["python3", "-m", "http.server", "8080"]

EXPOSE 8080