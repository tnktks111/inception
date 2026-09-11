# syntax=docker/dockerfile:1
FROM debian:12
RUN <<EOF 
mkdir -p /etc/nginx/conf.d /var/www/html
apt-get update
apt-get -y install nginx
rm -f /etc/nginx/sites-enabled/default
rm -f /var/www/html/index.nginx-debian.html
apt-get clean
rm -rf /var/lib/apt/lists/*
EOF
COPY conf /etc/nginx/conf.d/
CMD ["/usr/sbin/nginx", "-g", "daemon off;"]