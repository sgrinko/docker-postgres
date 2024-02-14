#!/bin/bash

# calculate day week
DOW=$(date +%u)
cd $BACKUP_PATH

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

if [ "$BACKUP_THREADS" = "" ]; then
    BACKUP_THREADS=4
fi

if [ "$DOW" = "6" ] ; then
    # make a full backup once a week (Saturday)
    BACKUPMODE=full
else
    # make an incremental backup on other days of the week
    BACKUPMODE=page
fi
if [ "$BACKUP_MODE" != "" ]; then
    # The backup creation mode is given forcibly
    BACKUPMODE=$BACKUP_MODE
fi

if [ "$BACKUP_STREAM" = "" ]; then
    BACKUP_STREAM="stream"
fi
if [[ "$BACKUP_STREAM" = "yes"  || "$BACKUP_STREAM" = "stream" ]]; then
    BACKUP_STREAM="--stream"
else
    BACKUP_STREAM=""
fi

if [ "$BACKUP_PATH" = "" ]; then
    BACKUP_PATH="/mnt/pgbak"
fi

if [ "$PGUSER" = "" ]; then
    PGUSER=postgres
fi

COUNT_DIR=`ls -l $BACKUP_PATH | grep "^d" | wc -l`

if [ "$COUNT_DIR" = "0" ]; then
   echo "Init new directory for backup: $BACKUP_PATH"
   /usr/bin/pg_probackup-$PG_MAJOR init -B $BACKUP_PATH -D $PGDATA
fi

if ! [ -d "$BACKUP_PATH/backups/$PG_MAJOR" ]; then
   echo "Create new instance for claster: $PG_MAJOR"
   /usr/bin/pg_probackup-$PG_MAJOR add-instance -B $BACKUP_PATH --instance=$PG_MAJOR -D $PGDATA
   /usr/bin/pg_probackup-$PG_MAJOR set-config -B $BACKUP_PATH --instance=$PG_MAJOR --retention-window=30 --compress-algorithm=zlib --compress-level=6
fi

IS_FULL=`/usr/bin/pg_probackup-$PG_MAJOR show --instance=$PG_MAJOR --backup-path=$BACKUP_PATH | grep FULL | grep 'OK\|DONE'`

if ! [ -f $PGDATA/archive_active.trigger ] ; then
    touch $PGDATA/archive_active.trigger
fi

if [[ "$IS_FULL" = "" || $BACKUPMODE = "full" ]] ; then
    echo "The initial backup must be type FULL ..."
    /usr/bin/pg_probackup-$PG_MAJOR backup -d postgres --backup-path=$BACKUP_PATH -b full $BACKUP_STREAM --instance=$PG_MAJOR -w --threads=$BACKUP_THREADS
else
    if [[ $BACKUPMODE = "merge" ]]; then
        # в этом режиме здесь всегда PAGE
        /usr/bin/pg_probackup-$PG_MAJOR backup --backup-path=$BACKUP_PATH -b page $BACKUP_STREAM --instance=$PG_MAJOR -w --threads=$BACKUP_THREADS
    else
        /usr/bin/pg_probackup-$PG_MAJOR backup --backup-path=$BACKUP_PATH -b $BACKUPMODE $BACKUP_STREAM --instance=$PG_MAJOR -w --threads=$BACKUP_THREADS
    fi
    STATUS=`/usr/bin/pg_probackup-$PG_MAJOR show --backup-path=$BACKUP_PATH --instance=$PG_MAJOR --format=json | jq -c '.[].backups[0].status'`
    LAST_STATE=${STATUS//'"'/''}
    if [[ "$LAST_STATE" = "CORRUPT" || "$LAST_STATE" = "ERROR" || "$LAST_STATE" = "ORPHAN" ]] ; then
        # You need to run a full backup, as an error occurred with incremental
        # Perhaps the loss of the segment at Failover ...
        /usr/bin/pg_probackup-$PG_MAJOR backup --backup-path=$BACKUP_PATH -b full $BACKUP_STREAM --instance=$PG_MAJOR -w --threads=$BACKUP_THREADS
    fi
fi

if [[ $BACKUPMODE = "merge" ]] ; then
    # объединяем старые бэкапы в соответствии с настройками
    /usr/bin/pg_probackup-$PG_MAJOR delete --backup-path=$BACKUP_PATH --instance=$PG_MAJOR --delete-expired --delete-wal --merge-expired --no-validate --threads=$BACKUP_THREADS
else
    # чистим старые бэкапы в соответствии с настройками
    /usr/bin/pg_probackup-$PG_MAJOR delete --backup-path=$BACKUP_PATH --instance=$PG_MAJOR --delete-expired --delete-wal --threads=$BACKUP_THREADS
fi

# collecting statistics on backups
/usr/bin/pg_probackup-$PG_MAJOR show --backup-path=$BACKUP_PATH > ~postgres/backups.txt
/usr/bin/pg_probackup-$PG_MAJOR show --backup-path=$BACKUP_PATH --archive >> ~postgres/backups.txt

echo "" >> ~postgres/backups.txt
echo "Место на бэкапном устройстве:" >> ~postgres/backups.txt
df -h $BACKUP_PATH >> ~postgres/backups.txt

ERRORS_COUNT=`grep -c ERROR ~postgres/backups.txt`
EMAIL_SUBJECT=""
if [[ "$ERRORS_COUNT" -ne "0" ]] ; then
    EMAIL_SUBJECT="Report backups error"
else
    EMAIL_SUBJECT="Report backups"
fi

# send mail to DBA
if [ "$EMAIL_SEND" = "yes" ]; then
    (echo '<html>List of all cluster backups:<br><pre>' ; cat ~postgres/backups.txt ; echo '</pre></html>';) | sendEmail -o tls=no -o message-content-type=html -o message-charset=utf-8 -f "$EMAIL_HOSTNAME" -t $EMAILTO -s $EMAIL_SERVER -u $EMAIL_SUBJECT
fi
