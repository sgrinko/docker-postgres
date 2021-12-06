#!/bin/bash

# $1 - the type mode backup: delta or page (default) or full (create full backup)
# $2 - the sign stream wal mode backup: "yes" or "stream" (default) or other to sign "archive"
# $3 - the count threads: 4 (default) or this number

# calculate day week
DOW=$(date +%u)

# Processing external variables

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

if [ "$BACKUP_STREAM" = "" ]; then
    BACKUP_STREAM="stream"
fi
if [[ "$BACKUP_STREAM" = "yes" || "$BACKUP_STREAM" = "stream" ]]; then
    BACKUP_STREAM="--stream"
else
    BACKUP_STREAM=""
fi

if [ "$BACKUP_PATH" = "" ]; then
    BACKUP_PATH="/mnt/pgbak"
fi

# Processing external parameters. Priority!

if [ "$DOW" = "6" ] ; then
    # make a full backup once a week (Saturday)
    BACKUP_MODE=full
else
    # make an incremental backup on other days of the week
    BACKUP_MODE=page
fi

if [ "$1" != "" ]; then
    # The backup creation mode is given forcibly
    BACKUP_MODE=$1
fi

BACKUP_STREAM="--stream"
if [ "$2" != "" ]; then
  if [[ "$2" = "stream" || "$2" = "yes" ]]; then
      BACKUP_STREAM="--stream"
  else
      BACKUP_STREAM=""
  fi
fi

if [ "$3" != "" ]; then
    BACKUP_THREADS=$3
fi


cd $BACKUP_PATH

COUNT_DIR=`ls -l $BACKUP_PATH | grep "^d" | wc -l`

if [ "$COUNT_DIR" = "0" ]; then
   # init new directory for backup
   su - postgres -c "/usr/bin/pg_probackup-$PG_MAJOR init -B $BACKUP_PATH -D $PGDATA"
fi

if ! [ -d "$BACKUP_PATH/backups/$PG_MAJOR" ]; then
   # create new instance for claster
   su - postgres -c "/usr/bin/pg_probackup-$PG_MAJOR add-instance -B $BACKUP_PATH --instance=$PG_MAJOR -D $PGDATA"
   su - postgres -c "/usr/bin/pg_probackup-$PG_MAJOR set-config -B $BACKUP_PATH --instance=$PG_MAJOR --retention-window=7 --compress-algorithm=zlib --compress-level=6"
fi

IS_FULL=`su - postgres -c "/usr/bin/pg_probackup-$PG_MAJOR show --instance=$PG_MAJOR --backup-path=$BACKUP_PATH | grep FULL | grep 'OK\|DONE'"`


if ! [ -f $PGDATA/archive_active.trigger ] ; then
    su - postgres -c "touch $PGDATA/archive_active.trigger"
fi

if [[ "$IS_FULL" = "" || $BACKUP_MODE = "full" ]] ; then
    # Full backup needs to be forcibly
    su - postgres -c "/usr/bin/pg_probackup-$PG_MAJOR backup --backup-path=$BACKUP_PATH -b full $BACKUP_STREAM --instance=$PG_MAJOR -w --threads=$BACKUP_THREADS --delete-expired --delete-wal"
else
    # Backup type depends on day or input parameter
    su - postgres -c "/usr/bin/pg_probackup-$PG_MAJOR backup --backup-path=$BACKUP_PATH -b $BACKUP_MODE $BACKUP_STREAM --instance=$PG_MAJOR -w --threads=$BACKUP_THREADS --delete-expired --delete-wal"
    STATUS=`su - postgres -c "/usr/bin/pg_probackup-$PG_MAJOR show --backup-path=$BACKUP_PATH --instance=$PG_MAJOR --format=json | jq -c '.[].backups[0].status'"`
    LAST_STATE=${STATUS//'"'/''}
    if [[ "$LAST_STATE" = "CORRUPT" || "$LAST_STATE" = "ERROR" || "$LAST_STATE" = "ORPHAN" ]] ; then
        # You need to run a full backup, as an error occurred with incremental
        # Perhaps the loss of the segment at Failover ...
        su - postgres -c "/usr/bin/pg_probackup-$PG_MAJOR backup --backup-path=$BACKUP_PATH -b full $BACKUP_STREAM --instance=$PG_MAJOR -w --threads=$BACKUP_THREADS --delete-expired --delete-wal"
    fi
fi


# collecting statistics on backups
su - postgres -c "/usr/bin/pg_probackup-$PG_MAJOR show --backup-path=$BACKUP_PATH > ~postgres/backups.txt"
su - postgres -c "/usr/bin/pg_probackup-$PG_MAJOR show --backup-path=$BACKUP_PATH --archive >> ~postgres/backups.txt"

cat ~postgres/backups.txt

# send mail to DBA
if [ "$EMAIL_SEND" = "yes" ]; then
    (echo '<html>List of all cluster backups:<br><pre>' ; cat ~postgres/backups.txt ; echo '</pre></html>';) | sendEmail -f "$EMAIL_HOSTNAME" -t $EMAILTO -s $EMAIL_SERVER -u "Report backups"
fi
