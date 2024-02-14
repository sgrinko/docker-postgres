#!/bin/bash
#  создаём все необходимые каталоги
mkdir -p /mnt/pgbak2 /var/log/postgresql1 /var/log/pgbouncer1 /var/log/mamonsu1 /var/lib/pgsql/14_1 /usr/share/postgres/14_1/tsearch_data
chown 999:999 /var/log/postgresql1 /var/lib/pgsql/14_1 /var/log/pgbouncer1 /var/log/mamonsu1 /mnt/pgbak2 /usr/share/postgres/14_1 /usr/share/postgres/14_1/tsearch_data
# стартуем докер
docker run --rm --name my_postgres_14 --shm-size 2147483648 -p 5433:5432/tcp --stop-timeout 60 \
           -v /var/lib/pgsql/14_1/data:/var/lib/postgresql/data \
           -v /var/log/postgresql1:/var/log/postgresql \
           -v /mnt/pgbak2/:/mnt/pgbak \
           -v /usr/share/postgres/14_1/tsearch_data:/usr/share/postgresql/tsearch_data \
           -e POSTGRES_PASSWORD=postgres -e POSTGRES_HOST_AUTH_METHOD=trust -e DEPLOY_PASSWORD=postgres -e PGBOUNCER_PASSWORD=postgres -e TZ="Etc/UTC" \
           grufos/postgres:14.11 \
           -c shared_preload_libraries="plugin_debugger,plpgsql_check,pg_stat_statements,auto_explain,pg_buffercache,pg_cron,shared_ispell,pg_prewarm" -c shared_ispell.max_size=70MB
