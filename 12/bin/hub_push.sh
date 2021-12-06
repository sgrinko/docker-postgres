#!/bin/bash

# postgres
echo "========"
echo "postgres"
echo "========"
if ! docker image ls | grep "grufos/postgres" ; then
    echo "    push ..."
    docker tag docker_postgres:latest grufos/postgres:12.9
    docker push grufos/postgres:12.9
fi

# pganalyze
echo "========="
echo "pganalyze"
echo "========="
if ! docker image ls | grep "grufos/pganalyze" ; then
    echo "    push ..."
    docker tag docker_analyze:latest grufos/pganalyze:12.9
    docker push grufos/pganalyze:12.9
fi

# pgprobackup
echo "==========="
echo "pgprobackup"
echo "==========="
if ! docker image ls | grep "grufos/pgprobackup" ; then
    echo "    push ..."
    docker tag docker_pgprobackup_backup:latest grufos/pgprobackup:12.9
    docker push grufos/pgprobackup:12.9
fi

# pgprorestore
echo "============"
echo "pgprorestore"
echo "============"
if ! docker image ls | grep "grufos/pgprorestore" ; then
    echo "    push ..."
    docker tag docker_pgprobackup_restore:latest grufos/pgprorestore:12.9
    docker push grufos/pgprorestore:12.9
fi
