#!/bin/bash
docker run --name my_postgres_13 --shm-size 2147483648 -p 5433:5432/tcp \
           -v /var/lib/pgsql/13_1/data:/var/lib/postgresql/data \
           -v /var/log/postgresql1:/var/log/postgresql \
           -v /mnt/pgbak2/:/mnt/pgbak \
           -v /usr/share/postgres/tsearch_data:/usr/share/postgresql/tsearch_data
           -e POSTGRES_PASSWORD=postgres -e POSTGRES_HOST_AUTH_METHOD=trust -e DEPLOY_PASSWORD=postgres -e TZ="Etc/UTC" \
           grufos/postgres:13.5 \
           -c shared_preload_libraries="plugin_debugger,pg_stat_statements,auto_explain,pg_buffercache,pg_cron,shared_ispell,pg_prewarm" -c shared_ispell.max_size=70MB
