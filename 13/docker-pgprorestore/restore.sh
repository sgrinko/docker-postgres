#!/bin/bash

#
# $TARGET_TIME - the time for which you need to recover, if empty, it will be according to the state of the backup itself
#                if time is specified, then $TARGET_ID  is ignored
# $TARGET_ID - backup label from command output pg_probackup show
# $BACKUP_THREADS - the count threads: 4 (default) or this number
#

if [ "$BACKUP_THREADS" = "" ]; then
    BACKUP_THREADS=4
fi

#if [ "$TARGET_TIME" = "" ]; then
#   if [ "$TARGET_ID" = "" ]; then
#       # set restore time to current (default)
#       TARGET_TIME=`date +"%F %T"`
#   fi
#fi

if [ "$BACKUP_PATH" = "" ]; then
    BACKUP_PATH="/mnt/pgbak"
fi

cd $BACKUP_PATH

rm -rf $PGDATA/*
mkdir -p $PGDATA
chmod go-rwx $PGDATA
chown -R postgres:postgres $PGDATA

echo ================================
echo 'start restore server ...'
echo ================================

if [ -n "$TARGET_ID" ] ; then
    su - postgres -c "/usr/bin/pg_probackup-$PG_MAJOR restore --recovery-target-action=promote --skip-block-validation --no-validate --threads=$BACKUP_THREADS --backup-path=$BACKUP_PATH --instance=$PG_MAJOR -D $PGDATA --recovery-target=immediate -i $TARGET_ID"
    echo "===================================="
    echo "restore to ID: $TARGET_ID"
elif [ -n "$TARGET_TIME" ] ; then
    su - postgres -c "/usr/bin/pg_probackup-$PG_MAJOR restore --recovery-target-action=promote --skip-block-validation --no-validate --threads=$BACKUP_THREADS --backup-path=$BACKUP_PATH --instance=$PG_MAJOR -D $PGDATA --recovery-target-time=\"$TARGET_TIME\""
    echo "===================================="
    echo "restore to time: $TARGET_TIME"
else
    su - postgres -c "/usr/bin/pg_probackup-$PG_MAJOR restore --recovery-target-action=promote --skip-block-validation --no-validate --threads=$BACKUP_THREADS --backup-path=$BACKUP_PATH --instance=$PG_MAJOR -D $PGDATA --recovery-target=latest"
    echo "===================================="
    echo "restore to latest"
fi
echo "===================================="
