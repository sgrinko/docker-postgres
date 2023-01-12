#!/bin/bash

set -euo pipefail

# pgbouncer
echo "========="
echo "pgbouncer"
echo "========="
if ! docker image ls | grep "grufos/pgbouncer" ; then
    echo "    push ..."
    docker tag 15_pgbouncer:latest grufos/pgbouncer:latest
    docker push grufos/pgbouncer:latest
    docker tag grufos/pgbouncer:latest grufos/pgbouncer:1.17.0
    docker push grufos/pgbouncer:1.17.0
fi

# postgres
echo "========"
echo "postgres"
echo "========"
if ! docker image ls | grep "grufos/postgres" ; then
    echo "    push ..."
    docker tag 15_postgres:latest grufos/postgres:latest
    docker push grufos/postgres:latest
    docker tag grufos/postgres:latest grufos/postgres:15.1
    docker push grufos/postgres:15.1
fi

# pgupgrade
echo "========="
echo "pgupgrade"
echo "========="
if ! docker image ls | grep "grufos/pgupgrade" ; then
    echo "    push ..."
    docker tag 15_pgupgrade:latest grufos/pgupgrade:latest
    docker push grufos/pgupgrade:latest
    docker tag grufos/pgupgrade:latest grufos/pgupgrade:15.1
    docker push grufos/pgupgrade:15.1
fi

# pganalyze
echo "========="
echo "pganalyze"
echo "========="
if ! docker image ls | grep "grufos/pganalyze" ; then
    echo "    push ..."
    docker tag 15_analyze:latest grufos/pganalyze:latest
    docker push grufos/pganalyze:latest
    docker tag grufos/pganalyze:latest grufos/pganalyze:15.1
    docker push grufos/pganalyze:15.1
fi

# pgprobackup
echo "==========="
echo "pgprobackup"
echo "==========="
if ! docker image ls | grep "grufos/pgprobackup" ; then
    echo "    push ..."
    docker tag 15_pgprobackup_backup:latest grufos/pgprobackup:latest
    docker push grufos/pgprobackup:latest
    docker tag grufos/pgprobackup:latest grufos/pgprobackup:15.1_2.5.10
    docker push grufos/pgprobackup:15.1_2.5.10
fi

# pgprorestore
echo "============"
echo "pgprorestore"
echo "============"
if ! docker image ls | grep "grufos/pgprorestore" ; then
    echo "    push ..."
    docker tag 15_pgprobackup_restore:latest grufos/pgprorestore:latest
    docker push grufos/pgprorestore:latest
    docker tag grufos/pgprorestore:latest grufos/pgprorestore:15.1_2.5.10
    docker push grufos/pgprorestore:15.1_2.5.10
fi

# mamonsu
echo "======="
echo "mamonsu"
echo "======="
if ! docker image ls | grep "grufos/mamonsu" ; then
    echo "    push ..."
    docker tag 15_mamonsu:latest grufos/mamonsu:latest
    docker push grufos/mamonsu:latest
    docker tag grufos/mamonsu:latest grufos/mamonsu:15_3.5.2
    docker push grufos/mamonsu:15_3.5.2
fi
