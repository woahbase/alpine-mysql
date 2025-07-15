# syntax=docker/dockerfile:1
#
ARG IMAGEBASE=frommakefile
#
FROM ${IMAGEBASE}
#
ARG TARGETPLATFORM
#
ENV \
    MYSQL_BACKUPDIR=/var/lib/mysql_backups \
    MYSQL_HOME=/var/lib/mysql \
    MYSQL_PORT=3306 \
    S6_USER=mysql \
    S6_USERHOME=/var/lib/mysql
#
RUN set -xe \
#
    # remove default user alpine as it seems to clash with user mysql
    # e.g claims mysql socket and fail healthcheck via socket
    && userdel -rf alpine \
    && addgroup -g ${PGID} -S ${S6_USER} \
    && adduser -u ${PUID} -G ${S6_USER} -h ${S6_USERHOME} -s /bin/false -D ${S6_USER} \
#
    && apk add --no-cache --purge -uU \
        bzip2 \
        gzip \
        openssl \
        tzdata \
        xz \
        zstd \
#
        mysql \
        mysql-client \
        mariadb \
        mariadb-backup \
        mariadb-client \
        mariadb-mytop \
        mariadb-server-utils \
        # no RocksDB plugin package available for these two
        $(if [ "${TARGETPLATFORM}" == "linux/386" ] \
          || [ "${TARGETPLATFORM}" == "linux/s390x" ]; \
          then echo ""; \
          else echo "mariadb-plugin-rocksdb"; \
        fi) \
#
    && mkdir -p /defaults \
    && mv /etc/my.cnf /defaults/my.cnf.default \
    && mv /etc/my.cnf.d /defaults/my.cnf.d.default \
#
    && rm -rf /var/cache/apk/* /tmp/*
#
COPY root/ /
#
VOLUME  ["${MYSQL_HOME}", "${MYSQL_BACKUPDIR}"]
#
EXPOSE ${MYSQL_PORT} 33060
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
