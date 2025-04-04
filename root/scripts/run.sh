#!/usr/bin/with-contenv bash
# reference: https://github.com/docker-library/mysql/blob/master/8.4/docker-entrypoint.sh
#            https://github.com/MariaDB/mariadb-docker/blob/master/11.8/docker-entrypoint.sh

if [ -n "${DEBUG}" ]; then set -ex; fi;
vecho () { if [ "${S6_VERBOSITY:-1}" -gt 0 ]; then echo "[$0] $@"; fi; }

MYSQL_HOME="${MYSQL_HOME:-/var/lib/mysql}"; # for backups
MYSQL_BACKUPDIR="${MYSQL_BACKUPDIR:-/var/lib/mysql_backups}"; # for backups
MYSQL_INITDIR=${MYSQL_INITDIR:-/initdb.d}; # for initializer files
MYSQL_SOCKET_PATH="${MYSQL_SOCKET_PATH:-/run/mysqld/mysqld.sock}";

if [ "X${EUID}" = "X0" ]; then vecho "must be run as a non-root mysql user."; exit 1; fi;

CMD="$1"; # required to select task to run

# usage: process_init_file FILENAME MYSQL_ARGS...
#    ie: process_init_file foo.sh mariadb -uroot
# (process a single initializer file, based on its extension. we define this
# function here, so that initializer scripts (*.sh) can use the same logic,
# potentially recursively, or override the logic used in subsequent calls)
process_init_file() {
    local f="$1"; shift;
    # default args for mysql
    local MYSQL_ARGS="${MYSQL_ARGS:- --user=${MYSQL_USER:-root}}";
    if [[ $# -gt 0 ]]; then MYSQL_ARGS="$@"; fi; # if args passed via cmdline, use those instead

    _my () { # can only be used after either root or admin user password have been setup
        MYSQL_PWD=${MYSQL_USER_PWD:-$MYSQL_ROOT_PWD} \
            mariadb $@;
    }

    case "$f" in
        *.sh|*.bash)
            if [ -x "$f" ];
            then
                vecho "Running $f";
                "$f";
            else
                vecho "Sourcing $f";
                . "$f";
            fi
        ;;
        *.sql)
            vecho "Loading $f";
            _my ${MYSQL_ARGS[@]} < "$f";
        ;;
        *.sql.gz)
            vecho "Extracting/loading $f";
            gunzip -c "$f" | _my ${MYSQL_ARGS[@]};
        ;;
        *.sql.xz)
            vecho "Extracting/loading $f";
            xzcat "$f" | _my ${MYSQL_ARGS[@]};
        ;;
        *.sql.zst)
            vecho "Extracting/loading $f";
            zstd -dc "$f" | _my ${MYSQL_ARGS[@]};
        ;;
        *)  vecho "Ignoring $f" ;;
    esac
}

if [ "${CMD^^}" == 'INITDB' ];
then # process initial db state and/or configurations (used by s6-init scripts)
    if [ -n "${MYSQL_INITDIR}" ] && [ -d "${MYSQL_INITDIR}" ];
    then
        vecho "Checking for initializer files in ${MYSQL_INITDIR}...";
        for f in $(find "${MYSQL_INITDIR}" -maxdepth 1 -type f 2>/dev/null | sort -u);
        do
            process_init_file "$f" ${@:2};
        done;
        vecho "Done.";
    fi;

elif [ "${CMD^^}" == 'BACKUP' ]; # backup single db
then
    DB="$2"; # required db name
    OPTS="${@:3}";
    if [ -z "${OPTS}" ]; then OPTS="--user=${MYSQL_USER:-root} --password=${MYSQL_USER_PWD:-$MYSQL_ROOT_PWD}"; fi;
    mariadb-dump \
        ${MYSQL_HOST:+ --host=$MYSQL_HOST} \
        --databases "${DB}" \
        ${OPTS[@]} \
        > ${MYSQL_BACKUPDIR}/${DB}.sql;

elif [ "${CMD^^}" == 'RESTORE' ]; # restore single db
then
    DB="$2"; # required db name
    OPTS="${@:3}";
    if [ -z "${OPTS}" ]; then OPTS="--user=${MYSQL_USER:-root} --password=${MYSQL_USER_PWD:-$MYSQL_ROOT_PWD}"; fi;
    mariadb \
        ${MYSQL_HOST:+ --host=$MYSQL_HOST} \
        --one-database "${DB}" \
        ${OPTS[@]} \
        < ${MYSQL_BACKUPDIR}/${DB}.sql; # backup must already exist

elif [ "${CMD^^}" == 'HEALTHCHECK' ]; # used in Dockerfile
then
    if [ -n "${MYSQL_HEALTHCHECK_USER:-$MYSQL_USER}" ] && [ -n "${MYSQL_HEALTHCHECK_USER_PWD:-$MYSQL_USER_PWD}" ];
    then
        mariadb \
            ${MYSQL_HOST:+ --host=$MYSQL_HOST} \
            --user=${MYSQL_HEALTHCHECK_USER:-$MYSQL_USER} \
            --password=${MYSQL_HEALTHCHECK_USER_PWD:-$MYSQL_USER_PWD} \
            --execute="${HEALTHCHECK_QUERY:-SHOW DATABASES;}";
    else # use socket/user access
        mariadb \
            -h localhost \
            --socket=${MYSQL_SOCKET_PATH} \
            --execute="${HEALTHCHECK_QUERY:-SHOW DATABASES;}";
    fi;

elif [ "${CMD^^}" == 'INSTALL-DB' ]; # runs as non-root user by default
then
    if [ ! -d "${MYSQL_HOME}/mysql" ];
    then
        vecho "Database system directory not found, initializing..."
        mariadb-install-db \
            --auth-root-authentication-method=normal \
            --cross-bootstrap \
            --datadir="${MYSQL_HOME}" \
            --default-time-zone=SYSTEM \
            --enforce-storage-engine= \
            --expire-logs-days=0 \
            --loose-innodb_buffer_pool_dump_at_shutdown=0 \
            --loose-innodb_buffer_pool_load_at_startup=0 \
            --old-mode='UTF8_IS_UTF8MB3' \
            --rpm \
            --skip-log-bin \
            --skip-test-db \
            --user="${S6_USER:-mysql}" \
            ${MYSQL_INSTALLDB_ARGS[@]} \
            ${MYSQLD_ARGS[@]} \
            ${@:2} \
        ;
        vecho 'Database initialized.'
    fi;

elif [ "${CMD^^}" == 'UPGRADE-DB' ]; # runs as non-root user by default
then
    vecho "Backing up system database to ${MYSQL_BACKUPDIR}/system_mysql_backup.sql";
    mariadb-dump \
        --skip-lock-tables \
        --replace \
        --databases mysql \
        --socket=${MYSQL_SOCKET_PATH} \
    > "${MYSQL_BACKUPDIR}/system_mysql_backup.sql" \
    && mariadb-upgrade \
        --upgrade-system-tables;

elif [ "${CMD^^}" == 'TEMP-SERVER-START' ]; # runs as non-root user by default
then
    if [ -f /run/mysqld/mysqld-temp.pid ] \
    && [ -n $(cat /run/mysqld/mysqld-temp.pid) ];
    then
        vecho "MySQL temporary server already running.";
        exit 0;
    else
        vecho "MySQL temporary server starting.";
        mariadbd \
            --default-time-zone=SYSTEM \
            --expire-logs-days=0 \
            --loose-innodb_buffer_pool_load_at_startup=0 \
            --skip-networking \
            --skip-slave-start \
            --skip-ssl \
            --socket=${MYSQL_SOCKET_PATH} \
            --ssl-ca='' \
            --ssl-cert='' \
            --ssl-key='' \
            --wsrep_on=OFF \
            ${MYSQLD_ARGS[@]} \
            ${@:2} \
            &
        echo $! > /run/mysqld/mysqld-temp.pid;
    fi;

elif [ "${CMD^^}" == 'WAIT-SERVER-READY' ]; # runs as non-root user by default
then # block until database ready
    vecho "Waiting for connection...";
    ret=6; # wait for upto 5x6=30 seconds
    until \
        mariadb \
            --protocol=socket \
            -uroot \
            -hlocalhost \
            --socket=${MYSQL_SOCKET_PATH} \
            --database=mysql \
            --skip-ssl \
            --skip-ssl-verify-server-cert \
            <<<'SELECT 1' &> /dev/null;
    do
        if [[ ret -eq 0 ]];
        then
            vecho "Could not connect to database. Exiting.";
            exit 1;
        fi;
        sleep 5;
        ((ret--));
    done;
    vecho "Found database connection.";

elif [ "${CMD^^}" == 'TEMP-SERVER-STOP' ]; # runs as non-root user by default
then
    MARIADB_PID="$(cat /run/mysqld/mysqld-temp.pid)";
    if [ ! -f /run/mysqld/mysqld-temp.pid ] \
    || [ -z "${MARIADB_PID}" ];
    then
        vecho "MySQL temporary server not running.";
        exit 0;
    else
        kill ${MARIADB_PID};
        wait ${MARIADB_PID} 2>/dev/null || true; # so we don't error when (usually) pid is not a child
        rm -f /run/mysqld/mysqld-temp.pid;
        vecho "MySQL temporary server stopped.";
    fi;
else
    echo "Usage: $0 <cmd> <additional args>";
    echo "cmd:";
    echo "  initdb <additional args>";
    echo "    load initializer files from ${MYSQL_INITDIR}";
    echo "  backup <dbname>";
    echo "    backup single db to ${MYSQL_BACKUPDIR}/<dbname>.sql";
    echo "  restore <dbname>";
    echo "    restore single db from ${MYSQL_BACKUPDIR}/<dbname>.sql";
    echo "  healthcheck";
    echo "    run healthcheck-query as \$MYSQL_HEALTHCHECK_USER";
    echo "    fallback to \$MYSQL_USER if defined";
    echo "    or fallback to socket user.";
    echo "  install-db <additional args>";
    echo "    setup database filesystem in ${MYSQL_HOME}";
    echo "    only when no databases exist.";
    echo "  upgrade-db";
    echo "    backup system database in ${MYSQL_BACKUPDIR}";
    echo "    then upgrade system database in ${MYSQL_HOME}";
    echo "  temp-server-start <additional args>";
    echo "    start a temporary-server listening to ${MYSQL_SOCKET_PATH}";
    echo "  wait-server-ready";
    echo "    wait maximum 30 seconds until temporary-server";
    echo "    becomes accessible.";
    echo "  temp-server-stop";
    echo "    stop temporary-server";
fi;
