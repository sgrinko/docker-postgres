#!/bin/bash

set -euo pipefail

# pgbouncer
#echo "========="
#echo "pgbouncer"
#echo "========="
#if ! docker image ls | grep "grufos/pgbouncer" ; then
#    echo "    push ..."
#    docker tag docker_pgbouncer:latest grufos/pgbouncer:latest
#    docker push grufos/pgbouncer:latest
#    docker tag grufos/pgbouncer:latest grufos/pgbouncer:1.16.1
#    docker push grufos/pgbouncer:1.16.1
#fi

# postgres
echo "========"
echo "postgres"
echo "========"
if ! docker image ls | grep "grufos/postgres" ; then
    echo "    push ..."
    docker tag docker_postgres:latest grufos/postgres:latest
#    docker push grufos/postgres:latest
    docker tag grufos/postgres:latest grufos/postgres:13.5
    docker push grufos/postgres:13.5
fi

# pganalyze
echo "========="
echo "pganalyze"
echo "========="
if ! docker image ls | grep "grufos/pganalyze" ; then
    echo "    push ..."
    docker tag docker_analyze:latest grufos/pganalyze:latest
#    docker push grufos/pganalyze:latest
    docker tag grufos/pganalyze:latest grufos/pganalyze:13.5
    docker push grufos/pganalyze:13.5
fi

# pgprobackup
echo "==========="
echo "pgprobackup"
echo "==========="
if ! docker image ls | grep "grufos/pgprobackup" ; then
    echo "    push ..."
    docker tag docker_pgprobackup_backup:latest grufos/pgprobackup:latest
#    docker push grufos/pgprobackup:latest
    docker tag grufos/pgprobackup:latest grufos/pgprobackup:13.5
    docker push grufos/pgprobackup:13.5
fi

# pgprorestore
echo "============"
echo "pgprorestore"
echo "============"
if ! docker image ls | grep "grufos/pgprorestore" ; then
    echo "    push ..."
    docker tag docker_pgprobackup_restore:latest grufos/pgprorestore:latest
#    docker push grufos/pgprorestore:latest
    docker tag grufos/pgprorestore:latest grufos/pgprorestore:13.5
    docker push grufos/pgprorestore:13.5
fi

# mamonsu
echo "======="
echo "mamonsu"
echo "======="
if ! docker image ls | grep "grufos/mamonsu" ; then
    echo "    push ..."
    docker tag docker_mamonsu:latest grufos/mamonsu:latest
#    docker push grufos/mamonsu:latest
    docker tag grufos/mamonsu:latest grufos/mamonsu:13_3.2.0
    docker push grufos/mamonsu:13_3.2.0
fi
