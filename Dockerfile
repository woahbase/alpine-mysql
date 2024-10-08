# syntax=docker/dockerfile:1
#
ARG IMAGEBASE=frommakefile
#
FROM ${IMAGEBASE}
#
RUN set -xe \
    && apk add --no-cache --purge -uU \
        mysql \
        mysql-client \
        mariadb \
        mariadb-backup \
        mariadb-client \
        mariadb-mytop \
        mariadb-plugin-rocksdb \
        mariadb-server-utils \
        tzdata \
    # remove default user alpine as it seems clash with user mysql
    # e.g claims mysql socket and fail healthcheck via socket
    && userdel -rf alpine \
    && mkdir -p /defaults \
    && mv /etc/my.cnf /defaults/my.cnf.default \
    && mv /etc/my.cnf.d /defaults/my.cnf.d.default \
    && rm -rf /var/cache/apk/* /tmp/*
#
ENV \
    S6_USER=mysql \
    S6_USERHOME=/var/lib/mysql
#
COPY root/ /
#
VOLUME  ["/var/lib/mysql", "/var/lib/mysql_backups", "/etc/my.cnf.d", "/etc/my.initdb.d"]
#
EXPOSE 3306 3366
#
HEALTHCHECK \
    --interval=2m \
    --retries=5 \
    --start-period=5m \
    --timeout=10s \
    CMD \
        /scripts/run.sh healthcheck \
    || exit 1
#
ENTRYPOINT ["/init"]
