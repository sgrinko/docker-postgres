#!/bin/sh

set -e

# Perform all actions as $POSTGRES_USER
if [ "$POSTGRES_USER" = "" ]; then
    POSTGRES_USER=postgres
fi
if [ "$POSTGRES_DB" = "" ]; then
    POSTGRES_DB=postgres
fi
if [ "$DEV_SCHEMA" = "" ]; then
    DEV_SCHEMA=dbo
fi
export PGUSER="$POSTGRES_USER"
export PGDATABASE="$POSTGRES_DB"

POSTGIS_VERSION="${POSTGIS_VERSION%%+*}"

# Create the 'template_postgis' template db
su - postgres -c "psql -f /usr/local/bin/pre.sql -v DEPLOY_PASSWORD=\"$DEPLOY_PASSWORD\""

# Load extension into both template_database and $POSTGRES_DB
for DB in "$POSTGRES_DB" template_extension "${@}"; do
    echo "Updating DB: '$DB'"

    su - postgres -c "psql --dbname=\"$DB\" -f /usr/local/bin/db_all.sql"

    if [ "$DB" = "postgres" ] ; then
        su - postgres -c "psql --dbname=\"$DB\" -f /usr/local/bin/db_postgres.sql"
    else
        su - postgres -c "psql --dbname=\"$DB\" -f /usr/local/bin/db_notpostgres.sql -v POSTGIS_VERSION=\"$POSTGIS_VERSION\" -v DB=\"$DB\" -v DEV_SCHEMA=\"$DEV_SCHEMA\" -v POSTGRES_PASSWORD=\"$POSTGRES_PASSWORD\""
        if [ "$DB" != "template_extension" ] ; then
            su - postgres -c "psql --dbname=\"$DB\" -f /usr/local/bin/db_target.sql -v DB=\"$DB\" -v DEV_SCHEMA=\"$DEV_SCHEMA\""
        fi
    fi
done

su - postgres -c "psql -f /usr/local/bin/post.sql"
