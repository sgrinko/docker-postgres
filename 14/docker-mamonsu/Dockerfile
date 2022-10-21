# Based on:
# https://hub.docker.com/_/debian
#
FROM debian:buster-slim

LABEL maintainer="Sergey Grinko <sergey.grinko@gmail.com>"

ENV DEBIAN_RELEASE buster
ENV PG_MAJOR 14
ENV BACKUP_PATH /mnt/pgbak
# version mamonsu
ENV VERSION 3.5.2

# explicitly set user/group IDs
RUN set -eux; \
    groupadd -r postgres --gid=999; \
    useradd -r -g postgres --uid=999 --home-dir=/var/lib/postgresql --shell=/bin/bash postgres; \
    mkdir -p /var/lib/postgresql/data;

COPY ./pg_probackup.py /usr/local/bin
COPY ./config.py /usr/local/bin
COPY ./wal.py /usr/local/bin

RUN apt-get update \
      && apt-get install -y wget gnupg sendemail dumb-init make dpkg-dev debhelper python3-dev python3-setuptools\
      # ... install psql ...
      && echo "deb http://apt.postgresql.org/pub/repos/apt $DEBIAN_RELEASE-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
      && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
      && apt-get update \
      && apt-get install -y postgresql-client-$PG_MAJOR \
      # ... install mamonsu ...
      && mkdir -p /etc/mamonsu \
      && cd /tmp \
      && mkdir -p build_mamonsu \
      && cd /tmp/build_mamonsu \
      && wget --quiet https://github.com/postgrespro/mamonsu/archive/refs/tags/$VERSION.tar.gz \
      && tar xzf /tmp/build_mamonsu/$VERSION.tar.gz --directory /tmp/build_mamonsu/ \
      && cp /usr/local/bin/pg_probackup.py /tmp/build_mamonsu/mamonsu-$VERSION/mamonsu/plugins/system/linux/pg_probackup.py \
      && cp /usr/local/bin/config.py /tmp/build_mamonsu/mamonsu-$VERSION/mamonsu/lib/config.py \
      && cp /usr/local/bin/wal.py /tmp/build_mamonsu/mamonsu-$VERSION/mamonsu/plugins/pgsql/wal.py \
      && cd /tmp/build_mamonsu/mamonsu-$VERSION && python3 setup.py build && python3 setup.py install \
      && ln -s /usr/local/bin/mamonsu /usr/bin/mamonsu \
      && mkdir -p /var/log/mamonsu \
      && chown -R postgres:postgres /var/log/mamonsu \
      # ... install pg_probackup ...
      && echo "deb [arch=amd64] https://repo.postgrespro.ru/pg_probackup/deb/ $DEBIAN_RELEASE main-$DEBIAN_RELEASE" > /etc/apt/sources.list.d/pg_probackup.list \
      && wget -O - https://repo.postgrespro.ru/pg_probackup/keys/GPG-KEY-PG_PROBACKUP | apt-key add - \
      && apt-get update \
      && apt-get install -y \
           pg-probackup-$PG_MAJOR \
      && mkdir -p $BACKUP_PATH \
      && chown -R postgres:postgres $BACKUP_PATH \
      && chown -R postgres:postgres /etc/mamonsu /var/log/mamonsu \
      # ... cleaning ...
      && rm -rf /tmp/build_mamonsu \
      && rm -rf /etc/mamonsu/* \
      && rm -rf /var/lib/apt/lists/* \
      && apt-get purge -y make dpkg-dev debhelper \
      && apt-get -f install \
      && apt-get -y autoremove \
      && apt-get -y clean \
      && apt-get -y autoclean

COPY ./mamonsu_start.sh /usr/local/bin
COPY ./agent.conf /usr/local/bin/agent.conf.tmpl
COPY ./pg_partition.py /usr/local/bin/pg_partition.py.tmpl
COPY ./pg_jobs_check.py /usr/local/bin/pg_jobs_check.py.tmpl
COPY ./pre.sql /var/lib/postgresql
COPY ./mamonsu_right_add.sql /var/lib/postgresql
COPY ./bootstrap_post.sql /var/lib/postgresql

RUN chown postgres:postgres /var/lib/postgresql/*.sql \
    && chmod +x /usr/local/bin/*.sh

USER postgres
ENTRYPOINT [ "dumb-init", "/usr/local/bin/mamonsu_start.sh" ]
