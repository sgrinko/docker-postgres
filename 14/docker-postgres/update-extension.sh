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
if [ "$EMAIL_SERVER" = "" ]; then
    EMAIL_SERVER=mail.company.ru
fi
if [ "$ENV_DB_VALUE" = "" ]; then
    ENV_DB_VALUE=DEV
fi

export PGUSER="$POSTGRES_USER"
export PGDATABASE="$POSTGRES_DB"

# Create the 'template_extension' template db
su - postgres -c "cd /usr/local/bin/ && psql -f pre.sql -v DEPLOY_PASSWORD=\"$DEPLOY_PASSWORD\" -v PGBOUNCER_PASSWORD=\"$PGBOUNCER_PASSWORD\""

# Load extension into both USER DB and $POSTGRES_DB
for DB in "$POSTGRES_DB" "${@}"; do
    echo "Updating DB: '$DB'"

    su - postgres -c "cd /usr/local/bin/ && psql --dbname=\"$DB\" -f db_all.sql -v email_server=\"$EMAIL_SERVER\""

    if [ "$DB" = "postgres" ] ; then
        su - postgres -c "cd /usr/local/bin/ && psql --dbname=\"$DB\" -f db_postgres.sql -v email_server=\"$EMAIL_SERVER\""
    else
        su - postgres -c "cd /usr/local/bin/ && psql --dbname=\"$DB\" -f db_notpostgres.sql -v IS_SETUPDB=\"true\" -v DEV_SCHEMA=\"$DEV_SCHEMA\" -v POSTGRES_PASSWORD=\"$POSTGRES_PASSWORD\" -v email_server=\"$EMAIL_SERVER\" -v environment_db_value=\"$ENV_DB_VALUE\""
        if [ "$DB" != "template_extension" ] ; then
            su - postgres -c "cd /usr/local/bin/ && psql --dbname=\"$DB\" -f db_target.sql -v DEV_SCHEMA=\"$DEV_SCHEMA\" -v email_server=\"$EMAIL_SERVER\""
        fi
    fi
done

su - postgres -c "cd /usr/local/bin/ && psql -XtqA -f post.sql | psql"
su - postgres -c "cd /usr/local/bin/ && psql -f post_warning.sql"

# specifies a specific Email server for sending letters
sed -i "s!adm.email_smtp_server = 'mail.company.ru'!adm.email_smtp_server = '$EMAIL_SERVER'!g" $PGDATA/postgresql.conf

su - postgres -c "psql -c 'select pg_reload_conf();'"
