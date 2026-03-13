# syntax=docker/dockerfile:1
FROM debian:12
RUN groupadd -r mysql && useradd -r -g mysql mysql --home-dir /var/lib/mysql
ARG GOSU_VERSION=1.19
RUN <<EOF1
    set -eux
    apt-get update
    apt-get install -y --no-install-recommends \
        gettext-base \
        ca-certificates
    savedAptMark="$(apt-mark showmanual)"
    apt-get install -y --no-install-recommends wget
    dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"
    wget -q -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"
    apt-mark auto '.*' > /dev/null
    [ -z "$savedAptMark" ] || apt-mark manual $savedAptMark
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false
    chmod +x /usr/local/bin/gosu

    mkdir /docker-entrypoint-initdb.d

    mkdir -p /var/lib/mysql/mysql
    touch /var/lib/mysql/mysql/user.frm

    export DEBIAN_FRONTEND=noninteractive
    apt-get install -y --no-install-recommends mariadb-server
    apt-get clean
    rm -rf /var/lib/apt/lists/* 

    rm -rf /var/lib/mysql
    mkdir -p /var/lib/mysql /run/mysqld
    chown -R mysql:mysql /var/lib/mysql /run/mysqld
    chmod 1777 /run/mysqld

    find /etc/mysql/ -name '*.cnf' -print0 \
        | xargs -0 grep -lZE '^(bind-address|log|user\s)' \
        | xargs -rt -0 sed -Ei 's/^(bind-address|log|user\s)/#&/'; \

    printf "[mariadb]\nhost-cache-size=0\nskip-name-resolve\n" > /etc/mysql/mariadb.conf.d/05-skipcache.cnf
    
    if [ -L /etc/mysql/my.cnf ]; then \
        sed -i -e '/includedir/ {N;s/\(.*\)\n\(.*\)/\n\2\n\1/}' /etc/mysql/mariadb.cnf; \
    fi
EOF1


COPY docker-entrypoint.sh /usr/local/bin/

ENTRYPOINT ["docker-entrypoint.sh"]
