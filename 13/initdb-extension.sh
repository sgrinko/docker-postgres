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
cp -f /var/lib/postgresql/pg_hba.conf $PGDATA
cp -f /var/lib/postgresql/pg_ident.conf $PGDATA
cp -f /var/lib/postgresql/postgresql.conf $PGDATA

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
        "${psql[@]}" --dbname="$DB" -f /usr/local/bin/db_notpostgres.sql -v POSTGIS_VERSION="$POSTGIS_VERSION" -v DB="$DB" -v DEV_SCHEMA="$DEV_SCHEMA" -v POSTGRES_PASSWORD="$POSTGRES_PASSWORD"
    fi
done

"${psql[@]}" -f /usr/local/bin/post.sql

