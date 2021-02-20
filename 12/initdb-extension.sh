#!/bin/sh

set -e

if [ "$POSTGRES_USER" = "" ]; then
    POSTGRES_USER=postgres
fi
if [ "$POSTGRES_DB" = "" ]; then
    POSTGRES_DB=postgres
fi
if [ "$DEV_SCHEMA" = "" ]; then
    DEV_SCHEMA=dbo
fi

# Perform all actions as $POSTGRES_USER
export PGUSER="$POSTGRES_USER"
export PGDATABASE="$POSTGRES_DB"

POSTGIS_VERSION="${POSTGIS_VERSION%%+*}"

echo "------------"
echo "-- initdb --"
echo "------------"

# copy start configuration files to pgdata
if [ 'trust' = "$POSTGRES_HOST_AUTH_METHOD" ]; then
    # create entrypoint for trust
    sed "s/md5/trust/g" /var/lib/postgresql/pg_hba.conf > $PGDATA/pg_hba.conf
else
    # the default is password entry (md5)
    cp -f /var/lib/postgresql/pg_hba.conf $PGDATA
fi
cp -f /var/lib/postgresql/pg_ident.conf $PGDATA
if [ -n "$TZ" ]; then
    TZ_R=${TZ/'/'/'\/'}
    # specifies a specific time zone for the server time zone
    sed "s/timezone = 'UTC'/timezone = '$TZ_R'/g" /var/lib/postgresql/postgresql.conf > $PGDATA/postgresql.conf
else
    cp -f /var/lib/postgresql/postgresql.conf $PGDATA
fi

"${psql[@]}" -c "select pg_reload_conf();"

# Create the 'template_extension' template db
"${psql[@]}" -f /usr/local/bin/pre.sql -v DEPLOY_PASSWORD="$DEPLOY_PASSWORD"

# Load extension into template_extension database and $POSTGRES_DB
for DB in "$POSTGRES_DB" template_extension ; do
    echo "Loading extensions into $DB"

    "${psql[@]}" --dbname="$DB" -f /usr/local/bin/db_all.sql

    if [ "$DB" = "postgres" ] ; then
        "${psql[@]}" --dbname="$DB" -f /usr/local/bin/db_postgres.sql
    else
        "${psql[@]}" --dbname="$DB" -f /usr/local/bin/db_notpostgres.sql -v IS_POSTGIS_VERSION=false -v DB="$DB" -v DEV_SCHEMA="$DEV_SCHEMA" -v POSTGRES_PASSWORD="$POSTGRES_PASSWORD"
    fi
done

"${psql[@]}" -f /usr/local/bin/post.sql

