#!/bin/bash

set -e

CONFIG_DIR=/etc/mamonsu

if [ ! -f ${CONFIG_DIR}/agent.conf ]; then
  cp -f /usr/local/bin/agent.conf.tmpl  ${CONFIG_DIR}/agent.conf
fi
mkdir -p ${CONFIG_DIR}/plugins
if [ ! -f ${CONFIG_DIR}/plugins/pg_partition.py ]; then
  cp -f /usr/local/bin/pg_partition.py.tmpl  ${CONFIG_DIR}/plugins/pg_partition.py
fi
if [ ! -f ${CONFIG_DIR}/plugins/__init__.py ]; then
  touch  ${CONFIG_DIR}/plugins/__init__.py
fi

# ... correct mamonsu conf file ...
sed -i "s/host = PGHOST/host = ${PGHOST:-127.0.0.1}/g" ${CONFIG_DIR}/agent.conf \
      && sed -i "s/password = MAMONSU_PASSWORD/password = ${MAMONSU_PASSWORD:-None}/g" ${CONFIG_DIR}/agent.conf \
      && sed -i "s/port = PGPORT/port = ${PGPORT:-5432}/g" ${CONFIG_DIR}/agent.conf \
      && sed -i "s/client = CLIENT_HOSTNAME/client = $CLIENT_HOSTNAME/g" ${CONFIG_DIR}/agent.conf \
      && sed -i "s/address = ZABBIX_SERVER_IP/address = $ZABBIX_SERVER_IP/g" ${CONFIG_DIR}/agent.conf \
      && sed -i "s/port = ZABBIX_SERVER_PORT/port = ${ZABBIX_SERVER_PORT:-10051}/g" ${CONFIG_DIR}/agent.conf \
      && sed -i "s/interval = INTERVAL_PGBUFFERCACHE/interval = ${INTERVAL_PGBUFFERCACHE:-1200}/g" ${CONFIG_DIR}/agent.conf \
      && sed -i "s/enabled = PGPROBACKUP_ENABLED/enabled = ${PGPROBACKUP_ENABLED:-False}/g" ${CONFIG_DIR}/agent.conf \
      && sed -i "s/pg_probackup_path = \/usr\/bin\/pg_probackup-PGPROBACKUP_PG_MAJOR/pg_probackup_path = \/usr\/bin\/pg_probackup-${PG_MAJOR}/g" ${CONFIG_DIR}/agent.conf \
      && sed -i "s/host = MAMONSU_AGENTHOST/host = ${MAMONSU_AGENTHOST:-127.0.0.1}/g" ${CONFIG_DIR}/agent.conf \
      && sed -i "s/enabled = MEMORYLEAKDIAGNOSTIC_ENABLED/enabled = ${MEMORYLEAKDIAGNOSTIC_ENABLED:-True}/g" ${CONFIG_DIR}/agent.conf \
      && sed -i "s/private_anon_mem_threshold = MEMORYLEAKDIAGNOSTIC_THRESHOLD/private_anon_mem_threshold = ${MEMORYLEAKDIAGNOSTIC_THRESHOLD:-4GB}/g" ${CONFIG_DIR}/agent.conf

# Create the 'mamonsu' DB and get all list DBs
DB_ALL=`psql -qAXt -f /var/lib/postgresql/pre.sql -v MAMONSU_PASSWORD="$MAMONSU_PASSWORD"`

# Name of the table version
TABLE_CHECK="${VERSION/'.'/'_'}"
# Dual pass to remove the second point
TABLE_CHECK="timestamp_master_${TABLE_CHECK/'.'/'_'}"
if psql -qtAX -c "select case when not pg_is_in_recovery() and not exists(select * from pg_class where relname = '$TABLE_CHECK') then 1 else 0 end as master" mamonsu | grep '1' ; then
   echo "bootstrap DB mamonsu ..."
   if [ "$PGPASSWORD" = "" ]; then
     /usr/bin/mamonsu bootstrap -M mamonsu -U postgres -x -d mamonsu --port=${PGPORT:-5432} --host=${PGHOST:-127.0.0.1};
   else
     /usr/bin/mamonsu bootstrap -M mamonsu -U postgres -x -d mamonsu --port=${PGPORT:-5432} --password=$PGPASSWORD --host=${PGHOST:-127.0.0.1};
   fi
fi

# setup DBs for monitoring at mamonsu
for DB in $DB_ALL ; do
    echo "Updating '$DB'"
    psql -qtAX --dbname="$DB" -f /var/lib/postgresql/mamonsu_right_add.sql
done

# generate templates...
cd ${CONFIG_DIR}
/usr/bin/mamonsu export template template.xml --add-plugins ${CONFIG_DIR}/plugins

# start services...
cd /
exec /usr/bin/mamonsu -a ${CONFIG_DIR}/plugins -c ${CONFIG_DIR}/agent.conf
