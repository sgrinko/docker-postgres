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
if [ "$EMAIL_SERVER" = "" ]; then
    EMAIL_SERVER=mail.company.ru
fi
if [ "$ENV_DB_VALUE" = "" ]; then
    ENV_DB_VALUE=DEV
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
    sed "s/md5/$POSTGRES_HOST_AUTH_METHOD/g" /usr/local/bin/pg_hba.conf > $PGDATA/pg_hba.conf
else
    # the default is password entry (md5)
    cp -f /usr/local/bin/pg_hba.conf $PGDATA
fi
cp -f /usr/local/bin/pg_ident.conf $PGDATA
cp -f /usr/local/bin/postgresql.conf $PGDATA
if [ -n "$TZ" ]; then
    # specifies a specific time zone for the server time zone
    sed -i "s!timezone = 'UTC'!timezone = '$TZ'!g" $PGDATA/postgresql.conf
    sed -i "s!cron.timezone = 'UTC'!cron.timezone = '$TZ'!g" $PGDATA/postgresql.conf
fi

# specifies a specific Email server for sending letters
sed -i "s!adm.email_smtp_server = 'mail.company.ru'!adm.email_smtp_server = '$EMAIL_SERVER'!g" $PGDATA/postgresql.conf

psql -c "select pg_reload_conf();"

cd /usr/local/bin/

# Create the 'template_extension' template DB and application DB
if [ "$APP_DB" != "" ]; then
  psql -f pre.sql -v DEPLOY_PASSWORD="$DEPLOY_PASSWORD" -v PGBOUNCER_PASSWORD="$PGBOUNCER_PASSWORD" -v APP_DB="$APP_DB"
else
  psql -f pre.sql -v DEPLOY_PASSWORD="$DEPLOY_PASSWORD" -v PGBOUNCER_PASSWORD="$PGBOUNCER_PASSWORD"
fi

# Load extension into template_extension database and $POSTGRES_DB
for DB in "$POSTGRES_DB" template_extension "$APP_DB" ; do
  if [ -n "$DB" ]; then
    echo "Loading extensions into $DB"

    psql --dbname="$DB" -f db_all.sql -v email_server="$EMAIL_SERVER"

    if [ "$DB" = "postgres" ] ; then
        psql --dbname="$DB" -f db_postgres.sql -v email_server="$EMAIL_SERVER"
    else
        psql --dbname="$DB" -f db_notpostgres.sql -v IS_SETUPDB=false -v DEV_SCHEMA="$DEV_SCHEMA" -v POSTGRES_PASSWORD="$POSTGRES_PASSWORD" -v email_server="$EMAIL_SERVER" -v environment_db_value="$ENV_DB_VALUE"
        if [ "$DB" != "template_extension" ] ; then
            psql --dbname="$DB" -f db_target.sql -v DEV_SCHEMA="$DEV_SCHEMA" -v email_server="$EMAIL_SERVER"
        fi
    fi
  fi
done

psql -XtqA -f post.sql | psql
psql -f post_warning.sql
