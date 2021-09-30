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

# Check on the need to initialize the catalog of the FTS
COUNT_DIR=`ls -l /usr/share/postgresql/tsearch_data/ | wc -l`
if [ "$COUNT_DIR" = "1" ]; then
   # init new directory for FTS
   echo "# restore files on FTS folder ..."
   tar -xzf /usr/share/postgresql/$PG_MAJOR/tsearch_data.tar.gz -C /usr/share/postgresql/tsearch_data/
fi

# copy start configuration files to pgdata
if [ 'md5' != "$POSTGRES_HOST_AUTH_METHOD" ]; then
    # create entrypoint for trust or another method access
    sed "s/md5/$POSTGRES_HOST_AUTH_METHOD/g" /var/lib/postgresql/pg_hba.conf > $PGDATA/pg_hba.conf
else
    # the default is password entry (md5)
    cp -f /var/lib/postgresql/pg_hba.conf $PGDATA
fi
cp -f /var/lib/postgresql/pg_ident.conf $PGDATA
if [ -n "$TZ" ]; then
    # specifies a specific time zone for the server time zone
    sed "s!timezone = 'UTC'!timezone = '$TZ'!g" /var/lib/postgresql/postgresql.conf > $PGDATA/postgresql.conf
else
    cp -f /var/lib/postgresql/postgresql.conf $PGDATA
fi

psql -c "select pg_reload_conf();"

# Create the 'template_extension' template db
psql -f /usr/local/bin/pre.sql -v DEPLOY_PASSWORD="$DEPLOY_PASSWORD"

# Load extension into template_extension database and $POSTGRES_DB
for DB in "$POSTGRES_DB" template_extension ; do
    echo "Loading extensions into $DB"

    psql --dbname="$DB" -f /usr/local/bin/db_all.sql

    if [ "$DB" = "postgres" ] ; then
        psql --dbname="$DB" -f /usr/local/bin/db_postgres.sql
    else
        psql --dbname="$DB" -f /usr/local/bin/db_notpostgres.sql -v IS_POSTGIS_VERSION=false -v DEV_SCHEMA="$DEV_SCHEMA" -v POSTGRES_PASSWORD="$POSTGRES_PASSWORD"
    fi
done

psql -f /usr/local/bin/post.sql
