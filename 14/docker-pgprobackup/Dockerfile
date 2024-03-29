# Based on:
# https://hub.docker.com/_/debian
#
FROM debian:bookworm-slim

LABEL maintainer="Sergey Grinko <sergey.grinko@gmail.com>"

ENV DEBIAN_RELEASE bookworm
ENV PG_MAJOR 14
ENV PGDATA /var/lib/postgresql/data
ENV BACKUP_PATH /mnt/pgbak

# explicitly set user/group IDs
RUN set -eux; \
    groupadd -r postgres --gid=999; \
    useradd -r -g postgres --uid=999 --home-dir=/var/lib/postgresql --shell=/bin/bash postgres; \
    mkdir -p /var/lib/postgresql/data; \
    chown -R postgres:postgres /var/lib/postgresql

RUN apt-get update \
      && apt-get install -y --no-install-recommends ca-certificates wget gnupg sendemail jq \
      # подключаем репозитарий сообщества PostgreSQL
      && echo "deb http://apt.postgresql.org/pub/repos/apt ${DEBIAN_RELEASE}-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
      && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
      # подключаем репозитарий архивной утилиты
      && echo "deb [arch=amd64] https://repo.postgrespro.ru/pg_probackup/deb/ $DEBIAN_RELEASE main-$DEBIAN_RELEASE" > /etc/apt/sources.list.d/pg_probackup.list \
      && wget -qO - https://repo.postgrespro.ru/pg_probackup/keys/GPG-KEY-PG-PROBACKUP | tee /etc/apt/trusted.gpg.d/pg_probackup.asc \
      # ... updating ...
      && apt-get update \
      # ... install pg-probackup and other...
      && apt-get install -y --no-install-recommends \
           pg-probackup-$PG_MAJOR \
           postgresql-client-$PG_MAJOR \
      && mkdir -p $BACKUP_PATH \
      && chown -R postgres:postgres $BACKUP_PATH \
      # ... cleaning ...
      && apt-get -f install \
      && apt-get -y autoremove \
      && apt-get -y clean \
      && apt-get -y autoclean \
      && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/apt/*

COPY ./backup.sh /usr/local/bin
COPY ./show.sh /usr/local/bin
# copy sql files
COPY ./sql/*.sql /usr/local/bin/

RUN chmod +x /usr/local/bin/*.sh

USER postgres
ENTRYPOINT [ "/usr/local/bin/backup.sh" ]
