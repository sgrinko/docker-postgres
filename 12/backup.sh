#!/bin/bash

# $1 - the count threads: 4 (default) or this number
# $2 - the type mode backup: delta (default), page or full (create full backup)
# $3 - the sign stream wal mode backup: yes (default) or other to sign "archive"

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
    BACKUP_MODE=delta
fi

if [ "$BACKUP_STREAM" = "" ]; then
    BACKUP_STREAM="yes"
fi
if [ "$BACKUP_STREAM" = "yes" ]; then
    BACKUP_STREAM="--stream"
else
    BACKUP_STREAM=""
fi

if [ "$BACKUP_PATH" = "" ]; then
    BACKUP_PATH="/mnt/pgbak"
fi

if [ "$1" != "" ]; then
    BACKUP_THREADS=$1
fi

if [ "$2" != "" ]; then
    BACKUP_MODE=$2
fi

if [ "$3" != "" ]; then
  if [ "$3" = "yes" ]; then
      BACKUP_STREAM="--stream"
  else
      BACKUP_STREAM=""
  fi
fi

cd $BACKUP_PATH

COUNT_DIR=`ls -l $BACKUP_PATH | grep "^d" | wc -l`

if [ "$COUNT_DIR" = "0" ]; then
   # init new directory for backup
   /usr/bin/pg_probackup-$PG_MAJOR init -B $BACKUP_PATH -D $PGDATA
fi

if ! [ -d "$BACKUP_PATH/$PG_MAJOR" ]; then
   # create new instance for claster
   /usr/bin/pg_probackup-$PG_MAJOR add-instance -B $BACKUP_PATH --instance=$PG_MAJOR -D $PGDATA
   /usr/bin/pg_probackup-$PG_MAJOR set-config -B $BACKUP_PATH --instance=$PG_MAJOR --retention-window=7 --compress-algorithm=zlib --compress-level=6
fi

IS_FULL=`su - postgres -c "/usr/bin/pg_probackup-$PG_MAJOR show --instance=$PG_MAJOR --backup-path=$BACKUP_PATH | grep FULL | grep 'OK\|DONE'"`


if ! [ -f $PGDATA/archive_active.trigger ] ; then
    su - postgres -c "touch $PGDATA/archive_active.trigger"
fi

# calculate day week
DOW=$(date +%u)

if [[ "$IS_FULL" = "" || $BACKUP_MODE = "full" ]] ; then
    su - postgres -c "/usr/bin/pg_probackup-$PG_MAJOR backup -d postgres --backup-path=$BACKUP_PATH -b full $BACKUP_STREAM --instance=$PG_MAJOR -w --threads=$BACKUP_THREADS --delete-expired"
else
   if [ "$DOW" = "6" ] ; then
      su - postgres -c "/usr/bin/pg_probackup-$PG_MAJOR backup -d postgres --backup-path=$BACKUP_PATH -b full $BACKUP_STREAM --instance=$PG_MAJOR -w --threads=$BACKUP_THREADS --delete-expired --delete-wal"
   else
      su - postgres -c "/usr/bin/pg_probackup-$PG_MAJOR backup -d postgres --backup-path=$BACKUP_PATH -b $BACKUP_MODE $BACKUP_STREAM --instance=$PG_MAJOR -w --threads=$BACKUP_THREADS --delete-expired --delete-wal"
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
