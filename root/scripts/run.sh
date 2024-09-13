#!/bin/bash

set -e;

CMD="$1";
DB="$2"; # optional

MYSQL_INIT_DB=${MYSQL_INIT_DB:-/etc/my.initdb.d}
MYSQL_BACKUPDIR="${MYSQL_BACKUPDIR:-/var/lib/mysql_backups}";

# from https://github.com/docker-library/mysql/blob/master/8.0/docker-entrypoint.sh
# usage: process_init_file FILENAME MYSQLCOMMAND...
#    ie: process_init_file foo.sh mysql -uroot
# (process a single initializer file, based on its extension. we define this
# function here, so that initializer scripts (*.sh) can use the same logic,
# potentially recursively, or override the logic used in subsequent calls)
process_init_file() {
    local f="$1"; shift
    local mysql=( "$@" )

    case "$f" in
        *.sh)     echo "$0: running $f"; . "$f" ;;
        *.sql)    echo "$0: loading $f"; "${mysql[@]}" < "$f"; echo ;;
        *.sql.gz) echo "$0: extracting/loading $f"; gunzip -c "$f" | "${mysql[@]}"; echo ;;
        *)        echo "$0: ignoring $f" ;;
    esac
    echo;
}

if [ ${CMD^^} == 'INITDB'  ];
then
    # process initial db state and/or configurations from /etc/mysql/initdb.d/
    for f in ${MYSQL_INIT_DB}/*; do
        process_init_file "$f" /usr/bin/mysql -u root -p"${MYSQL_ROOT_PWD}";
    done;
elif [ ${CMD^^} == 'BACKUP'  ]; # runs as root by default, recommended to run as $S6_USER (mysql)
then
    mysqldump \
        ${MYSQL_HOST:+ --host=$MYSQL_HOST} \
        --user="${MYSQL_USER}" \
        --password="${MYSQL_USER_PWD}" \
        --databases "${DB}" > ${MYSQL_BACKUPDIR}/${DB}.sql;
elif [ ${CMD^^} == 'RESTORE'  ]; # runs as root by default, recommended to run as $S6_USER (mysql)
then
    mysql \
        ${MYSQL_HOST:+ --host=$MYSQL_HOST} \
        --user="${MYSQL_USER}" \
        --password="${MYSQL_USER_PWD}" \
        --one-database "${DB}" < ${MYSQL_BACKUPDIR}/${DB}.sql;
elif [ ${CMD^^} == 'HEALTHCHECK'  ]; # runs as non-root user by default
then
    if [ -n "${MYSQL_HEALTHCHECK_USER:-$MYSQL_USER}" ] && [ -n "${MYSQL_HEALTHCHECK_USER_PWD:-$MYSQL_USER_PWD}" ];
    then
        s6-setuidgid ${S6_USER:-mysql} \
        mysql \
            ${MYSQL_HOST:+ --host=$MYSQL_HOST} \
            --user=${MYSQL_HEALTHCHECK_USER:-$MYSQL_USER} \
            --password=${MYSQL_HEALTHCHECK_USER_PWD:-$MYSQL_USER_PWD} \
            --execute="${HEALTHCHECK_QUERY:-SHOW DATABASES;}";
    else
        s6-setuidgid ${S6_USER:-mysql} \
        mysql \
            -h localhost \
            --socket=/run/mysqld/mysqld.sock \
            --execute="${HEALTHCHECK_QUERY:-SHOW DATABASES;}";
    fi;
fi;
