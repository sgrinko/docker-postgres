# Based on:
# https://hub.docker.com/_/debian
#
FROM debian:bullseye-slim

LABEL maintainer="Sergey Grinko <sergey.grinko@gmail.com>"

ENV DEBIAN_RELEASE bullseye
ENV PG_MAJOR 13
ENV BACKUP_PATH /mnt/pgbak
# version mamonsu
ENV VERSION 3.5.3

# explicitly set user/group IDs
RUN set -eux; \
    groupadd -r postgres --gid=999; \
    useradd -r -g postgres --uid=999 --home-dir=/var/lib/postgresql --shell=/bin/bash postgres; \
    mkdir -p /var/lib/postgresql/data;

COPY ./pg_probackup.py /usr/local/bin

RUN apt-get update \
      && apt-get install -y --no-install-recommends ca-certificates wget gnupg sendemail dumb-init make dpkg-dev debhelper python3-dev python3-setuptools\
      # ... install psql ...
      && echo "deb http://apt.postgresql.org/pub/repos/apt $DEBIAN_RELEASE-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
      && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
      && apt-get update \
      && apt-get install -y --no-install-recommends postgresql-client-$PG_MAJOR \
      # ... install mamonsu ...
      && mkdir -p /etc/mamonsu \
      && cd /tmp \
      && mkdir -p build_mamonsu \
      && cd /tmp/build_mamonsu \
      && wget --quiet https://github.com/postgrespro/mamonsu/archive/refs/tags/$VERSION.tar.gz \
      && tar xzf /tmp/build_mamonsu/$VERSION.tar.gz --directory /tmp/build_mamonsu/ \
      && cp /usr/local/bin/pg_probackup.py /tmp/build_mamonsu/mamonsu-$VERSION/mamonsu/plugins/system/linux/pg_probackup.py \
      && cd /tmp/build_mamonsu/mamonsu-$VERSION && python3 setup.py build && python3 setup.py install \
      && ln -s /usr/local/bin/mamonsu /usr/bin/mamonsu \
      && mkdir -p /var/log/mamonsu \
      && chown -R postgres:postgres /var/log/mamonsu \
      # ... install pg_probackup ...
      && echo "deb [ trusted=yes arch=amd64] https://repo.postgrespro.ru/pg_probackup/deb/ $DEBIAN_RELEASE main-$DEBIAN_RELEASE" > /etc/apt/sources.list.d/pg_probackup.list \
      && wget --no-check-certificate -O - https://repo.postgrespro.ru/pg_probackup/keys/GPG-KEY-PG_PROBACKUP | gpg --no-default-keyring --keyring gnupg-ring:/etc/apt/trusted.gpg.d/GPG-KEY-PG_PROBACKUP.gpg --import \
      && chmod 644 /etc/apt/trusted.gpg.d/GPG-KEY-PG_PROBACKUP.gpg \
      && apt-get update \
      && apt-get install -y --no-install-recommends \
           pg-probackup-$PG_MAJOR \
      && mkdir -p $BACKUP_PATH \
      && chown -R postgres:postgres $BACKUP_PATH \
      && chown -R postgres:postgres /etc/mamonsu /var/log/mamonsu \
      # ... cleaning ...
      && rm -rf /etc/mamonsu/* \
      && apt-get purge -y make dpkg-dev debhelper \
      && apt-get -f install \
      && apt-get -y autoremove \
      && apt-get -y clean \
      && apt-get -y autoclean \
      && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/apt/*

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
