# Based on:
# https://hub.docker.com/_/debian
#
FROM debian:buster-slim

LABEL maintainer="Sergey Grinko <sergey.grinko@gmail.com>"

ENV DEBIAN_RELEASE buster
ENV PG_MAJOR 13
ENV PGDATA /var/lib/postgresql/data
ENV BACKUP_PATH /mnt/pgbak

# explicitly set user/group IDs
RUN set -eux; \
    groupadd -r postgres --gid=999; \
    useradd -r -g postgres --uid=999 --home-dir=/var/lib/postgresql --shell=/bin/bash postgres; \
    mkdir -p /var/lib/postgresql/data; \
    chown -R postgres:postgres /var/lib/postgresql

RUN apt-get update \
      && apt-get install -y wget gnupg sendemail jq \
      && echo "deb [arch=amd64] https://repo.postgrespro.ru/pg_probackup/deb/ $DEBIAN_RELEASE main-$DEBIAN_RELEASE" > /etc/apt/sources.list.d/pg_probackup.list \
      && wget -O - https://repo.postgrespro.ru/pg_probackup/keys/GPG-KEY-PG_PROBACKUP | apt-key add - \
      # ... install psql ...
      && echo "deb http://apt.postgresql.org/pub/repos/apt $DEBIAN_RELEASE-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
      && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
      && apt-get update \
      && apt-get install -y postgresql-client-$PG_MAJOR \
      # ... install pg-probackup ...
      && apt-get install -y \
           pg-probackup-$PG_MAJOR \
      && mkdir -p $BACKUP_PATH \
      && chown -R postgres:postgres $BACKUP_PATH \
      # ... cleaning ...
      && rm -rf /var/lib/apt/lists/* \
      && apt-get -f install \
      && apt-get -y autoremove \
      && apt-get -y clean \
      && apt-get -y autoclean

COPY ./backup.sh /usr/local/bin
COPY ./show.sh /usr/local/bin
COPY ./check_cluster.sh /usr/local/bin

RUN chmod +x /usr/local/bin/*.sh

USER postgres
ENTRYPOINT [ "/usr/local/bin/backup.sh" ]
