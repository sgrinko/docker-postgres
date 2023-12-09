#!/bin/bash

# $1 - yes/no (the sign for send to email, yes - default)
# $2 - list of email recipients (separated by a space)

if [ "$EMAILTO" = "" ]; then
    EMAILTO="DBA-PostgreSQL@company.ru"
fi

if [ "$EMAIL_SERVER" = "" ]; then
    EMAIL_SERVER=mail.company.ru
fi

if [ "$EMAIL_HOSTNAME" = "" ]; then
    EMAIL_HOSTNAME=`hostname`
    EMAIL_HOSTNAME="noreplay@${EMAIL_HOSTNAME}.ru"
fi

if [ "$EMAIL_SEND" = "" ]; then
    EMAIL_SEND="yes"
fi

if [ "$BACKUP_PATH" = "" ]; then
    BACKUP_PATH="/mnt/pgbak"
fi

if [ "$1" != "" ]; then
    EMAIL_SEND=$1
fi

if [ "$2" != "" ]; then
    EMAILTO="$2"
fi

cd $BACKUP_PATH

# send mail to DBA
su - postgres -c "/usr/bin/pg_probackup-$PG_MAJOR show --backup-path=$BACKUP_PATH > ~postgres/backups.txt"
su - postgres -c "/usr/bin/pg_probackup-$PG_MAJOR show --backup-path=$BACKUP_PATH --archive >> ~postgres/backups.txt"

echo "" >> ~postgres/backups.txt
echo "Место на бэкапном устройстве:" >> ~postgres/backups.txt
df -h $BACKUP_PATH >> ~postgres/backups.txt

ERRORS_COUNT=`su - postgres -c "grep -c ERROR ~postgres/backups.txt"`
EMAIL_SUBJECT=""
if [[ "$ERRORS_COUNT" -ne "0" ]] ; then
    EMAIL_SUBJECT="Report backups error"
else
    EMAIL_SUBJECT="Report backups"
fi

cat ~postgres/backups.txt
if [ "$EMAIL_SEND" = "yes" ]; then
    (echo '<html>List of all cluster backups:<br><pre>' ; cat ~postgres/backups.txt ; echo '</pre></html>';) | sendEmail -f "$EMAIL_HOSTNAME" -t $EMAILTO -s $EMAIL_SERVER -u $EMAIL_SUBJECT
fi
