docker run -p 127.0.0.1:5433:5432/tcp --shm-size 2147483648 \
           -e POSTGRES_PASSWORD=postgres \
           -e POSTGRES_HOST_AUTH_METHOD=trust \
           -e DEPLOY_PASSWORD=postgres \
           -e TZ="Etc/UTC" \
           grufos/postgres:14.7 \
           -c shared_preload_libraries="plugin_debugger,plpgsql_check,pg_stat_statements,auto_explain,pg_buffercache,pg_cron,shared_ispell,pg_prewarm" \
           -c shared_ispell.max_size=70MB
