#!/bin/bash

set -xe;

CMD="$1";
DB="$2";

if [ ${CMD^^} == 'BACKUP'  ];
then
    mysqldump -u "${MYSQL_USER}" -p"${MYSQL_USER_PWD}" --databases "${DB}" > /var/lib/mysql/backups/${DB}.sql;
elif [ ${CMD^^} == 'RESTORE'  ];
then
    mysql -u "${MYSQL_USER}" -p"${MYSQL_USER_PWD}" --one-database "${DB}" < /var/lib/mysql/backups/${DB}.sql;
fi;
