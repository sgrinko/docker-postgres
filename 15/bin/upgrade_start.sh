#!/bin/bash
#  создаём все необходимые каталоги
mkdir -p /mnt/pgbak2 /var/log/postgresql1 /var/log/pgbouncer1 /var/log/mamonsu1 /var/lib/pgsql/15_1 /var/lib/pgsql/15_1/14 /usr/share/postgres/15_1/tsearch_data
chown 999:999 /var/log/postgresql1 /var/lib/pgsql/15_1 /var/lib/pgsql/15_1/14 /var/log/pgbouncer1 /var/log/mamonsu1 /mnt/pgbak2 /usr/share/postgres/15_1 /usr/share/postgres/15_1/tsearch_data
clear
# запускаем сборку
rm -rf /usr/share/postgres/15_1/*
rm -rf /var/lib/pgsql/15_1/*
cp -rpf /var/lib/pgsql/14_1 /var/lib/pgsql/15_1/14
docker-compose -f "postgres-pgupgrade.yml" up --build "$@"