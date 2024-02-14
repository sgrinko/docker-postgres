#!/bin/bash
#  создаём все необходимые каталоги
SRC="15"
DEST="16"
mkdir -p /mnt/pgbak2 /var/log/postgresql1 /var/log/mamonsu1 /var/lib/pgsql/${DEST}_1 /usr/share/postgres/${DEST}_1
chown 999:999 /mnt/pgbak2 /var/log/postgresql1 /var/log/mamonsu1 /var/lib/pgsql/${DEST}_1 /usr/share/postgres/${DEST}_1
rm -rf /usr/share/postgres/${DEST}_1/*
rm -rf /var/lib/pgsql/${DEST}_1/*
mkdir -p /var/lib/pgsql/${DEST}_1/${DEST} /var/lib/pgsql/${DEST}_1/$SRC /usr/share/postgres/${DEST}_1/tsearch_data
chown 999:999 /var/lib/pgsql/${DEST}_1/${DEST} /var/lib/pgsql/${DEST}_1/$SRC /usr/share/postgres/${DEST}_1/tsearch_data
cp -rpf /var/lib/pgsql/${SRC}_1/* /var/lib/pgsql/${DEST}_1/$SRC
clear
# запускаем сборку
docker-compose -f "postgres-pgupgrade.yml" up --build "$@"
