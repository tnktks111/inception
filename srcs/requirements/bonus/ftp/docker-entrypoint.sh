#!/bin/bash
set -e

require_env() {
    local var_name="$1"
    if [ -z "${!var_name:-}" ]; then
        echo "Error: required environment variable '$var_name' is not set." >&2
        exit 1
    fi
}

if [ -n "$FTP_PASSWORD_FILE" ] && [ -f "$FTP_PASSWORD_FILE" ]; then
    FTP_PASSWORD=$(cat "$FTP_PASSWORD_FILE")
fi

require_env FTP_USER
require_env FTP_PASSWORD
require_env FTP_PASV_ADDRESS

sed "s|__FTP_PASV_ADDRESS__|${FTP_PASV_ADDRESS}|g" /etc/vsftpd.conf.template > /etc/vsftpd.conf

mkdir -p /var/www/html/wp-content
chgrp -R www-data /var/www/html/wp-content
chmod -R g+rwX /var/www/html/wp-content

if ! id "$FTP_USER" &>/dev/null; then
    echo "Creating FTP user: $FTP_USER"

    useradd -d /var/www/html/wp-content -s /bin/bash -g www-data "$FTP_USER"
    echo "$FTP_USER:$FTP_PASSWORD" | chpasswd
fi

echo "Starting vsftpd..."
exec vsftpd /etc/vsftpd.conf