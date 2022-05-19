# Based on:
# https://hub.docker.com/_/postgres
#     https://github.com/docker-library/postgres
# https://hub.docker.com/r/postgis/postgis
#    https://github.com/postgis/docker-postgis
#
FROM postgres:13.7

LABEL maintainer="Sergey Grinko <sergey.grinko@gmail.com>"

ENV LANG ru_RU.utf8

ENV POSTGIS_MAJOR 3
ENV DEBIAN_RELEASE buster
ENV BACKUP_PATH /mnt/pgbak
ENV POSTGRES_INITDB_ARGS "--locale=ru_RU.UTF8 --data-checksums"
ENV RUM_VERSION 1.3.9

RUN localedef -i ru_RU -c -f UTF-8 -A /usr/share/locale/locale.alias ru_RU.UTF-8 \
      && apt-get update \
      && apt-get install -y wget freetds-dev freetds-common git make gcc postgresql-server-dev-$PG_MAJOR libicu-dev sendemail htop mc systemtap-sdt-dev \
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
           postgresql-$PG_MAJOR-pldebugger \
           postgresql-$PG_MAJOR-plpgsql-check \
           postgresql-$PG_MAJOR-tds-fdw \
           libkrb5-dev \
      && sed -i "s/text size = 64512/text size = 1262485504/g" /etc/freetds/freetds.conf \
      && cd /tmp \
      && mkdir -p build_ext \
      # ====== hunspell_dicts
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
      # ====== pg_tsparser
      && cd /tmp/build_ext \
      && git clone https://github.com/postgrespro/pg_tsparser \
      && cd pg_tsparser \
      && make USE_PGXS=1 install \
      # shared_ispell
      && cd /tmp/build_ext \
      && git clone https://github.com/postgrespro/shared_ispell \
      && cd shared_ispell \
      && make USE_PGXS=1 \
      && make USE_PGXS=1 install \
      # ====== pg_variables
      && cd /tmp/build_ext \
      && git clone https://github.com/postgrespro/pg_variables \
      && cd pg_variables \
      && make USE_PGXS=1 \
      && make USE_PGXS=1 install \
      # ====== rum
      && cd /tmp/build_ext \
      && git clone https://github.com/postgrespro/rum --branch $RUM_VERSION  --single-branch \
      && cd rum \
      && make USE_PGXS=1 \
      && make USE_PGXS=1 install \
      # ====== pg_cron
      && cd /tmp/build_ext \
      && git clone https://github.com/citusdata/pg_cron \
      && cd pg_cron \
      && make \
      && make install \
      # ====== pg_dbo_timestamp
      && cd /tmp/build_ext \
      && git clone https://github.com/pgcodekeeper/pg_dbo_timestamp \
      && cd pg_dbo_timestamp \
      && make USE_PGXS=1 install \
      # ====== pg_background
      && cd /tmp/build_ext \
      && git clone https://github.com/vibhorkum/pg_background \
      && cd pg_background \
      && make \
      && make install \
      # ====== clean build directory...
      && rm -rf /tmp/build_ext \
      # ====== create backup path ...
      && mkdir -p $BACKUP_PATH \
      && chmod 0777 $BACKUP_PATH \
      && chmod 0777 /var/log/postgresql \
      && chown postgres:postgres $BACKUP_PATH /var/log/postgresql \
      # ====== make files on folder tsearch_data for mapping ...
      && cd /usr/share/postgresql/$PG_MAJOR/tsearch_data \
      && tar -czf /usr/share/postgresql/$PG_MAJOR/tsearch_data.tar.gz . \
      && cd / \
      && ln -s /usr/share/postgresql/$PG_MAJOR/tsearch_data /usr/share/postgresql/ \
      # ====== clean all unused package...
      && apt-mark hold llvm-11-runtime \
      && rm -rf /var/lib/apt/lists/* \
      && apt-get purge -y gcc freetds-dev git make postgresql-server-dev-$PG_MAJOR libicu-dev *-dev* \
      && apt-get -f install \
      && apt-get -y autoremove \
      && apt-get -y clean \
      && apt-get -y autoclean

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
COPY ./check_cluster.sh /usr/local/bin
COPY ./pg_hba.conf /var/lib/postgresql
COPY ./pg_ident.conf /var/lib/postgresql
COPY ./postgresql.conf /var/lib/postgresql
COPY ./postgres /usr/local/sbin

RUN chmod +x /usr/local/bin/*.sh \
    && chmod +x /usr/local/sbin/postgres \
    && chmod +x /docker-entrypoint-initdb.d/*.sh

# We set the default STOPSIGNAL to SIGINT, which corresponds to what PostgreSQL
# calls "Fast Shutdown mode" wherein new connections are disallowed and any
# in-progress transactions are aborted, allowing PostgreSQL to stop cleanly and
# flush tables to disk, which is the best compromise available to avoid data
# corruption.
#
# Users who know their applications do not keep open long-lived idle connections
# may way to use a value of SIGTERM instead, which corresponds to "Smart
# Shutdown mode" in which any existing sessions are allowed to finish and the
# server stops when all sessions are terminated.
#
# See https://www.postgresql.org/docs/12/server-shutdown.html for more details
# about available PostgreSQL server shutdown signals.
#
# See also https://www.postgresql.org/docs/12/server-start.html for further
# justification of this as the default value, namely that the example (and
# shipped) systemd service files use the "Fast Shutdown mode" for service
# termination.
#
STOPSIGNAL SIGINT
#
# An additional setting that is recommended for all users regardless of this
# value is the runtime "--stop-timeout" (or your orchestrator/runtime's
# equivalent) for controlling how long to wait between sending the defined
# STOPSIGNAL and sending SIGKILL (which is likely to cause data corruption).
#
# The default in most runtimes (such as Docker) is 10 seconds, and the
# documentation at https://www.postgresql.org/docs/12/server-start.html notes
# that even 90 seconds may not be long enough in many instances.
