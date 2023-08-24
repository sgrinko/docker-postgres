# Based on:
# https://hub.docker.com/_/postgres
#     https://github.com/docker-library/postgres
# https://hub.docker.com/r/postgis/postgis
#    https://github.com/postgis/docker-postgis
#
FROM postgres:15.4
LABEL maintainer="Sergey Grinko <sergey.grinko@gmail.com>"

ENV PG_MAJOR_OLD 14

ENV PGBINOLD /usr/lib/postgresql/$PG_MAJOR_OLD/bin
ENV PGBINNEW /usr/lib/postgresql/$PG_MAJOR/bin

ENV PGDATAOLD /var/lib/postgresql/$PG_MAJOR_OLD/data
ENV PGDATANEW /var/lib/postgresql/$PG_MAJOR/data

ENV TSEARCHDATAOLD /usr/share/postgresql/$PG_MAJOR_OLD/tsearch_data
ENV TSEARCHDATANEW /usr/share/postgresql/$PG_MAJOR/tsearch_data

# режим копирования каталога PGDATA: HARDLINK, AUTO, COPY
ENV PGDATACOPY_MODE HARDLINK

ENV LANG ru_RU.utf8

ENV POSTGIS_MAJOR 3
ENV DEBIAN_RELEASE bullseye
ENV BACKUP_PATH /mnt/pgbak
ENV POSTGRES_INITDB_ARGS "--locale=ru_RU.UTF8 --data-checksums"
ENV RUM_VERSION 1.3.13

RUN localedef -i ru_RU -c -f UTF-8 -A /usr/share/locale/locale.alias ru_RU.UTF-8 \
      && apt-get update \
      && apt-get install -y --no-install-recommends ca-certificates jq wget freetds-dev freetds-common git make gcc postgresql-server-dev-$PG_MAJOR libicu-dev sendemail htop mc systemtap-sdt-dev vim \
      && apt-cache showpkg postgresql-$PG_MAJOR-postgis-$POSTGIS_MAJOR \
      && apt-get install -y --no-install-recommends \
# ставим пакеты для предыдущей версии
           postgresql-$PG_MAJOR_OLD \
           postgresql-server-dev-$PG_MAJOR_OLD \
           postgresql-$PG_MAJOR_OLD-postgis-$POSTGIS_MAJOR \
           postgresql-$PG_MAJOR_OLD-postgis-$POSTGIS_MAJOR-scripts \
           postgresql-plpython3-$PG_MAJOR_OLD \
           postgresql-$PG_MAJOR_OLD-repack \
           postgresql-$PG_MAJOR_OLD-pldebugger \
           postgresql-$PG_MAJOR_OLD-plpgsql-check \
           postgresql-$PG_MAJOR_OLD-tds-fdw \
           postgresql-$PG_MAJOR_OLD-cron \
           postgresql-$PG_MAJOR_OLD-rum \
# ставим пакеты для новой версии
           postgresql-server-dev-$PG_MAJOR \
           postgresql-$PG_MAJOR-postgis-$POSTGIS_MAJOR \
           postgresql-$PG_MAJOR-postgis-$POSTGIS_MAJOR-scripts \
           postgresql-plpython3-$PG_MAJOR \
           postgresql-$PG_MAJOR-repack \
           postgresql-$PG_MAJOR-pldebugger \
           postgresql-$PG_MAJOR-plpgsql-check \
           postgresql-$PG_MAJOR-tds-fdw \
           libkrb5-dev \
      && sed -i "s/;\ttext size = 64512/\ttext size = 1262485504/g" /etc/freetds/freetds.conf \
      && git config --global http.sslverify false \
      && mkdir -p /tmp/build_ext \
      && cd /tmp/build_ext \
      && rm -rf /tmp/build_ext/* \
# ====== hunspell_dicts
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
# ====== shared_ispell
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
#
# для предыдущей версии
#
      && export PATH=$PGBINOLD:$PATH \
      && mkdir -p /tmp/build_ext \
      && cd /tmp/build_ext \
      && rm -rf /tmp/build_ext/* \
# ====== hunspell_dicts 
      && git clone https://github.com/postgrespro/hunspell_dicts \
      && cd hunspell_dicts \
      && cd hunspell_en_us \
      && make USE_PGXS=1 \
      && PATH=$PATH make USE_PGXS=1 install \
      && cd ../hunspell_ru_ru \
      && make USE_PGXS=1 \
      && PATH=$PATH make USE_PGXS=1 install \
      && cd ../hunspell_ru_ru_aot \
      && make USE_PGXS=1 \
      && PATH=$PATH make USE_PGXS=1 install \
# ====== pg_tsparser
      && cd /tmp/build_ext \
      && git clone https://github.com/postgrespro/pg_tsparser \
      && cd pg_tsparser \
      && PATH=$PATH make USE_PGXS=1 install \
# ====== shared_ispell
      && cd /tmp/build_ext \
      && git clone https://github.com/postgrespro/shared_ispell \
      && cd shared_ispell \
      && make USE_PGXS=1 \
      && PATH=$PATH make USE_PGXS=1 install \
# ====== pg_dbo_timestamp
      && cd /tmp/build_ext \
      && git clone https://github.com/pgcodekeeper/pg_dbo_timestamp \
      && cd pg_dbo_timestamp \
      && PATH=$PATH make USE_PGXS=1 install \
# ====== pg_background
      && cd /tmp/build_ext \
      && git clone https://github.com/vibhorkum/pg_background \
      && cd pg_background \
      && make \
      && PATH=$PATH make install \
# ====== pg_variables
      && cd /tmp/build_ext \
      && git clone https://github.com/postgrespro/pg_variables \
      && cd pg_variables \
      && make USE_PGXS=1 \
      && PATH=$PATH make USE_PGXS=1 install \
# ====== clean all unused package...
      && apt-get purge -y gcc freetds-dev git make postgresql-server-dev-$PG_MAJOR postgresql-server-dev-$PG_MAJOR_OLD libicu-dev *-dev* \
      && apt-get -f install \
      && apt-get -y autoremove \
      && apt-get -y clean \
      && apt-get -y autoclean \
      && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/apt/*

COPY ./upgrade.sh /usr/local/bin
# copy postgres files
COPY ./pg_hba.conf /usr/local/bin
COPY ./pg_ident.conf /usr/local/bin
COPY ./postgresql.conf /usr/local/bin

RUN chmod +x /usr/local/bin/*.sh \
    && chown postgres:postgres /usr/local/bin/pg_hba.conf /usr/local/bin/pg_ident.conf /usr/local/bin/postgresql.conf


RUN mkdir -p "$PGDATAOLD" "$PGDATANEW" "$TSEARCHDATAOLD" "$TSEARCHDATANEW" \
	&& chown -R postgres:postgres /var/lib/postgresql "$PGDATAOLD" "$PGDATANEW"

WORKDIR /var/lib/postgresql

ENTRYPOINT ["upgrade.sh"]
