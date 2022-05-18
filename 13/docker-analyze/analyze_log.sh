#!/bin/bash
curr_date=`date -d "-1 day" +%F`
echo "Date of processing: $curr_date"

echo "# read names DBs ..."
DB_ALL=`psql -h ${PGHOST:-127.0.0.1} -p ${PGPORT:-5432} -XtqA -c "select string_agg(datname,' ') from pg_database where not datistemplate and datname not in ('postgres','mamonsu') limit 1;"`
VERSION=$PG_MAJOR

# check paths...
PGLOG=/var/log/postgresql
INSTANCE=data
CLUSTER=$VERSION/$INSTANCE
SCRIPT_PATH=/var/lib/postgresql
REPORT_PATH=$PGLOG/report
PGDATA=/var/lib/postgresql/$CLUSTER

if [ "$STAT_STATEMENTS" = "" ]; then
    STAT_STATEMENTS="false"
fi

mkdir -p $REPORT_PATH

if [ "$STAT_STATEMENTS" = "true" ]; then
  echo "# take statistic on duration...."
  for DB in $DB_ALL ; do
    echo "TOP duration statements on DB: $DB"
    echo "-- ======================================================================================================== --" >> $REPORT_PATH/${curr_date}_${DB}_report.txt
    echo "" >> $REPORT_PATH/${curr_date}_${DB}_report.txt
    echo "TOP duration statements on DB: $DB" >> $REPORT_PATH/${curr_date}_${DB}_report.txt
    echo "" >> $REPORT_PATH/${curr_date}_${DB}_report.txt
    psql -h ${PGHOST:-127.0.0.1} -p ${PGPORT:-5432} -f $SCRIPT_PATH/pg_stat_statements_report.sql -qt $DB >> $REPORT_PATH/${curr_date}_${DB}_report.txt
    bzip2 -f -9 $REPORT_PATH/${curr_date}_${DB}_report.txt
  done
fi

if [ ! -f $PGLOG/postgresql-$VERSION-${curr_date}_000000.log ]; then
  touch $PGLOG/postgresql-$VERSION-${curr_date}_000000.log
fi
# merge lot LOG files into one file
for file in $( ls $PGLOG/postgresql-$VERSION-${curr_date}*.log )
do
  echo "# Procesing: $file ..."
  if [ $file != $PGLOG/postgresql-$VERSION-${curr_date}_000000.log ]; then
      cat $file >> $PGLOG/postgresql-$VERSION-${curr_date}_000000.log
      rm $file
  fi
done

echo "# take pgbadger statistics ..."
cd $REPORT_PATH
LOG_LINE_PREFIX=`psql -h ${PGHOST:-127.0.0.1} -p ${PGPORT:-5432} -XtqA -c "select setting from pg_settings where name ~ 'log_line_prefix';"`
if [ -f $PGLOG/postgresql-$VERSION-${curr_date}_000000.log ]; then
    echo "# create statistics from logs ..."
    pgbadger -f stderr --quiet --prefix "$LOG_LINE_PREFIX"  --outfile ${curr_date}_pgbadger.html $PGLOG/postgresql-$VERSION-${curr_date}_000000.log
    echo "# archiving..."
    bzip2 -f -9 $REPORT_PATH/${curr_date}_pgbadger.html
    bzip2 -f -9 $PGLOG/postgresql-$VERSION-${curr_date}_000000.log
fi

echo "# Clean the old archives of logs .... Store the last 30 files..."
ls -t $PGLOG/postgresql*.log.bz2 | tail -n +31 | xargs -I{} rm {}
echo "# Clean the old report archives .... Store the last 30 files..."
ls -t $REPORT_PATH/*.html.bz2 | tail -n +31 | xargs -I{} rm {}
ls -t $REPORT_PATH/*.txt.bz2 | tail -n +31 | xargs -I{} rm {}

if [ "$STAT_STATEMENTS" = "true" ]; then
  echo "# reset sql statements statistic ...."
  for DB in $DB_ALL ; do
    echo "exec pg_stat_statements_reset() on DB: $DB"
    psql -qt -h ${PGHOST:-127.0.0.1} -p ${PGPORT:-5432} -c "select pg_stat_statements_reset();" $DB
  done
fi

DAY=`date -d "-1 day" +%a`

echo ""
echo "# -- =========================== --"
echo "# mamonsu.log -> mamonsu.log.$DAY.bz ..."
mv -f /var/log/mamonsu/mamonsu.log /var/log/mamonsu/mamonsu.log.$DAY
bzip2 -f -9 /var/log/mamonsu/mamonsu.log.$DAY
echo "# пожалуйста выполните рестарт контейнера mamonsu ..."
echo "# -- =========================== --"
echo ""
echo "# -- =========================== --"
echo "# pgbouncer.log -> pgbouncer.log.$DAY.bz ...(blocked)"
#mv -f /var/log/pgbouncer/pgbouncer.log /var/log/pgbouncer/pgbouncer.log.$DAY
#bzip2 -f -9 /var/log/pgbouncer/pgbouncer.log.$DAY
echo "# -- =========================== --"
echo ""
echo "# -- =========================== --"
echo "# pgbouncer send HUP signal...(blocked)"
#echo "psql -h ${PGBHOST:-127.0.0.1} -p ${PGBPORT:-6432} -c 'reload;' pgbouncer"
#psql -h ${PGBHOST:-127.0.0.1} -p ${PGBPORT:-6432} -c 'reload;' pgbouncer
echo "# -- =========================== --"
