# Based on:
# https://hub.docker.com/_/postgres
#     https://github.com/docker-library/postgres
# https://hub.docker.com/r/postgis/postgis
#    https://github.com/postgis/docker-postgis
#
FROM postgres:12.5

LABEL maintainer="Sergey Grinko <sergey.grinko@gmail.com>"

RUN localedef -i ru_RU -c -f UTF-8 -A /usr/share/locale/locale.alias ru_RU.UTF-8
ENV LANG ru_RU.utf8

ENV POSTGIS_MAJOR 3
ENV POSTGIS_VERSION 3.1.0+dfsg-1.pgdg100+1
ENV DEBIAN_RELEASE buster
ENV BACKUP_PATH /mnt/pgbak
ENV POSTGRES_INITDB_ARGS "--locale=ru_RU.UTF8 --data-checksums"

RUN apt-get update \
      && apt-get install -y wget freetds-dev freetds-common git make gcc postgresql-server-dev-$PG_MAJOR libicu-dev sendemail htop \
      && echo "deb [arch=amd64] https://repo.postgrespro.ru/pg_probackup/deb/ $DEBIAN_RELEASE main-$DEBIAN_RELEASE" > /etc/apt/sources.list.d/pg_probackup.list \
      && wget -O - https://repo.postgrespro.ru/pg_probackup/keys/GPG-KEY-PG_PROBACKUP | apt-key add - \
      && apt-get update \
      && apt-cache showpkg postgresql-$PG_MAJOR-postgis-$POSTGIS_MAJOR \
      && apt-get install -y --no-install-recommends \
           postgresql-$PG_MAJOR-postgis-$POSTGIS_MAJOR \
           postgresql-$PG_MAJOR-postgis-$POSTGIS_MAJOR-scripts \
           pg-probackup-$PG_MAJOR \
           postgresql-plpython3-$PG_MAJOR \
           postgresql-$PG_MAJOR-repack \
           postgresql-$PG_MAJOR-cron \
           postgresql-$PG_MAJOR-pldebugger \
           postgresql-$PG_MAJOR-plpgsql-check \
           postgresql-$PG_MAJOR-rum \
           postgresql-$PG_MAJOR-tds-fdw \
      && sed -i.bak "s/text size = 64512/text size = 1262485504/g" /etc/freetds/freetds.conf \
      && rm -rf /var/lib/apt/lists/* \
      && cd /tmp \
      && mkdir -p build_ext \
      && cd build_ext \
      && git clone https://github.com/postgrespro/hunspell_dicts \
      && cd hunspell_dicts \
      && cd hunspell_en_us \
      && make USE_PGXS=1 \
      && make USE_PGXS=1 install \
      && cd ../hunspell_ru_ru \
      && make USE_PGXS=1 \
      && make USE_PGXS=1 install \
      && cd ../hunspell_ru_ru_aot \
      && make USE_PGXS=1 \
      && make USE_PGXS=1 install \
      && cd /tmp/build_ext \
      && git clone https://github.com/postgrespro/pg_tsparser \
      && cd pg_tsparser \
      && make USE_PGXS=1 install \
      && cd /tmp/build_ext \
      && git clone https://github.com/postgrespro/shared_ispell \
      && cd shared_ispell \
      && make USE_PGXS=1 \
      && make USE_PGXS=1 install \
      && cd /tmp/build_ext \
      && git clone https://github.com/postgrespro/pg_variables \
      && cd pg_variables \
      && make USE_PGXS=1 \
      && make USE_PGXS=1 install \
      && cd /tmp/build_ext \
      && git clone https://github.com/pgcodekeeper/pg_dbo_timestamp \
      && cd pg_dbo_timestamp \
      && make USE_PGXS=1 install \
      && rm -rf /tmp/build_ext \
      && mkdir -p $BACKUP_PATH \
      && chmod 0777 $BACKUP_PATH \
      && chown postgres:postgres $BACKUP_PATH /var/log/postgresql

RUN mkdir -p /docker-entrypoint-initdb.d

COPY ./initdb-extension.sh /docker-entrypoint-initdb.d/10_extension.sh
COPY ./update-extension.sh /usr/local/bin
COPY ./pre.sql /usr/local/bin
COPY ./post.sql /usr/local/bin
COPY ./db_all.sql /usr/local/bin
COPY ./db_postgres.sql /usr/local/bin
COPY ./db_notpostgres.sql /usr/local/bin
COPY ./db_target.sql /usr/local/bin
COPY ./backup.sh /usr/local/bin
COPY ./show.sh /usr/local/bin
COPY ./pg_hba.conf /var/lib/postgresql
COPY ./pg_ident.conf /var/lib/postgresql
COPY ./postgresql.conf /var/lib/postgresql

RUN chmod +x /usr/local/bin/*.sh
