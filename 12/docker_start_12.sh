#!/bin/bash
docker run --rm --name my_postgres_12 --shm-size 2147483648 -p 5433:5432/tcp --stop-timeout 60 \
           -v /var/lib/pgsql/12_1/data:/var/lib/postgresql/data \
           -v /var/log/postgresql1:/var/log/postgresql \
           -v /mnt/pgbak2/:/mnt/pgbak \
           -v /usr/share/postgres/tsearch_data:/usr/share/postgresql/tsearch_data \
           -e POSTGRES_PASSWORD=postgres -e POSTGRES_HOST_AUTH_METHOD=trust -e DEPLOY_PASSWORD=postgres -e PGBOUNCER_PASSWORD=postgres -e TZ="Etc/UTC" \
           grufos/postgres:12.11 \
           -c shared_preload_libraries="plpgsql_check,plugin_debugger,pg_stat_statements,auto_explain,pg_buffercache,pg_cron,shared_ispell,pg_prewarm" -c shared_ispell.max_size=70MB
