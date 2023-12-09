# Based on:
# https://hub.docker.com/_/debian
#
FROM debian:bookworm-slim

LABEL maintainer="Sergey Grinko <sergey.grinko@gmail.com>"

ENV DEBIAN_RELEASE bookworm
ENV PG_MAJOR 13
ENV BACKUP_PATH /mnt/pgbak

# explicitly set user/group IDs
RUN set -eux; \
    groupadd -r postgres --gid=999; \
    useradd -r -g postgres --uid=999 --home-dir=/var/lib/postgresql --shell=/bin/bash postgres; \
    mkdir -p /var/lib/postgresql/data;

RUN apt-get update \
      && apt-get install -y --no-install-recommends ca-certificates wget gnupg sendemail bzip2 pgbadger \
      # ... install psql ...
      && echo "deb http://apt.postgresql.org/pub/repos/apt $DEBIAN_RELEASE-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
      && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
      && apt-get update \
      && apt-get install -y --no-install-recommends postgresql-client-$PG_MAJOR \
      # ... create dirs ...
      && mkdir -p /var/log/postgresql/report \
      && mkdir -p /var/log/pgbouncer \
      && mkdir -p /var/log/mamonsu \
      # ... cleaning ...
      && apt-get -f install \
      && apt-get -y autoremove \
      && apt-get -y clean \
      && apt-get -y autoclean \
      && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/apt/*

COPY ./analyze_log.sh /usr/local/bin
COPY ./pg_stat_statements_report.sql /var/lib/postgresql

RUN chown postgres:postgres /var/lib/postgresql/*.sql \
      && chown -R postgres:postgres /var/log/postgresql/report \
      && chown -R postgres:postgres /var/log/pgbouncer \
      && chown -R postgres:postgres /var/log/mamonsu \
      && chmod +x /usr/local/bin/*.sh

USER postgres
ENTRYPOINT [ "/usr/local/bin/analyze_log.sh" ]
