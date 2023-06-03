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

if [ "$BACKUP_MODE" = "" ]; then
    BACKUP_MODE=page
fi

if [ "$DOW" = "6" ] ; then
    # make a full backup once a week (Saturday)
    BACKUP_MODE=full
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
   /usr/bin/pg_probackup-$PG_MAJOR set-config -B $BACKUP_PATH --instance=$PG_MAJOR --retention-window=7 --compress-algorithm=zlib --compress-level=6
fi

IS_FULL=`/usr/bin/pg_probackup-$PG_MAJOR show --instance=$PG_MAJOR --backup-path=$BACKUP_PATH | grep FULL | grep 'OK\|DONE'`

if ! [ -f $PGDATA/archive_active.trigger ] ; then
    touch $PGDATA/archive_active.trigger
fi

if [[ "$IS_FULL" = "" || $BACKUP_MODE = "full" ]] ; then
    echo "The initial backup must be type FULL ..."
    /usr/bin/pg_probackup-$PG_MAJOR backup -d postgres --backup-path=$BACKUP_PATH -b full $BACKUP_STREAM --instance=$PG_MAJOR -w --threads=$BACKUP_THREADS --delete-expired --delete-wal
else
    # Backup type depends on day or input parameter
    /usr/bin/pg_probackup-$PG_MAJOR backup --backup-path=$BACKUP_PATH -b $BACKUP_MODE $BACKUP_STREAM --instance=$PG_MAJOR -w --threads=$BACKUP_THREADS --delete-expired --delete-wal
    STATUS=`/usr/bin/pg_probackup-$PG_MAJOR show --backup-path=$BACKUP_PATH --instance=$PG_MAJOR --format=json | jq -c '.[].backups[0].status'`
    LAST_STATE=${STATUS//'"'/''}
    if [[ "$LAST_STATE" = "CORRUPT" || "$LAST_STATE" = "ERROR" || "$LAST_STATE" = "ORPHAN" ]] ; then
        # You need to run a full backup, as an error occurred with incremental
        # Perhaps the loss of the segment at Failover ...
        /usr/bin/pg_probackup-$PG_MAJOR backup --backup-path=$BACKUP_PATH -b full $BACKUP_STREAM --instance=$PG_MAJOR -w --threads=$BACKUP_THREADS --delete-expired --delete-wal
    fi
fi

# collecting statistics on backups
/usr/bin/pg_probackup-$PG_MAJOR show --backup-path=$BACKUP_PATH > ~postgres/backups.txt
/usr/bin/pg_probackup-$PG_MAJOR show --backup-path=$BACKUP_PATH --archive >> ~postgres/backups.txt

ERRORS_COUNT=`grep -c ERROR ~postgres/backups.txt`
EMAIL_SUBJECT=""
if [[ "$ERRORS_COUNT" -ne "0" ]] ; then
    EMAIL_SUBJECT="Report backups error"
else
    EMAIL_SUBJECT="Report backups"
fi

# send mail to DBA
if [ "$EMAIL_SEND" = "yes" ]; then
    (echo '<html>List of all cluster backups:<br><pre>' ; cat ~postgres/backups.txt ; echo '</pre></html>';) | sendEmail -o message-content-type=html -o message-charset=utf-8 -f "$EMAIL_HOSTNAME" -t $EMAILTO -s $EMAIL_SERVER -u $EMAIL_SUBJECT
fi
