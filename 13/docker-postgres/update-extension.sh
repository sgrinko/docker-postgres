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

export PGUSER="$POSTGRES_USER"
export PGDATABASE="$POSTGRES_DB"

# Create the 'template_extension' template db
su - postgres -c "psql -f /usr/local/bin/pre.sql -v DEPLOY_PASSWORD=\"$DEPLOY_PASSWORD\" -v PGBOUNCER_PASSWORD=\"$PGBOUNCER_PASSWORD\""

# Load extension into both USER DB and $POSTGRES_DB
for DB in "$POSTGRES_DB" "${@}"; do
    echo "Updating DB: '$DB'"

    su - postgres -c "psql --dbname=\"$DB\" -f /usr/local/bin/db_all.sql -v email_server=\"$EMAIL_SERVER\""

    if [ "$DB" = "postgres" ] ; then
        su - postgres -c "psql --dbname=\"$DB\" -f /usr/local/bin/db_postgres.sql -v email_server=\"$EMAIL_SERVER\""
    else
        su - postgres -c "psql --dbname=\"$DB\" -f /usr/local/bin/db_notpostgres.sql -v IS_SETUPDB=\"true\" -v DEV_SCHEMA=\"$DEV_SCHEMA\" -v POSTGRES_PASSWORD=\"$POSTGRES_PASSWORD\" -v email_server=\"$EMAIL_SERVER\""
        if [ "$DB" != "template_extension" ] ; then
            su - postgres -c "psql --dbname=\"$DB\" -f /usr/local/bin/db_target.sql -v DEV_SCHEMA=\"$DEV_SCHEMA\" -v email_server=\"$EMAIL_SERVER\""
        fi
    fi
done

su - postgres -c "psql -f /usr/local/bin/post.sql"

# specifies a specific Email server for sending letters
sed -i "s!adm.email_smtp_server = 'mail.company.ru'!adm.email_smtp_server = '$EMAIL_SERVER'!g" $PGDATA/postgresql.conf

su - postgres -c "psql -c 'select pg_reload_conf();'"
