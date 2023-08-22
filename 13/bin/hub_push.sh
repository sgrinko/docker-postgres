#!/bin/bash
VERSION=13
MINOR=12

set -euo pipefail

# pgbouncer
#echo "========="
#echo "pgbouncer"
#echo "========="
#if ! docker image ls | grep "grufos/pgbouncer" ; then
#    echo "    push ..."
#    docker tag ${VERSION}_pgbouncer:latest grufos/pgbouncer:latest
#    docker push grufos/pgbouncer:latest
#    docker tag grufos/pgbouncer:latest grufos/pgbouncer:1.19.0
#    docker push grufos/pgbouncer:1.19.0
#fi

# postgres
echo "========"
echo "postgres"
echo "========"
if ! docker image ls | grep "grufos/postgres" ; then
    echo "    push ..."
    docker tag ${VERSION}_postgres:latest grufos/postgres:latest
#    docker push grufos/postgres:latest
    docker tag grufos/postgres:latest grufos/postgres:${VERSION}.${MINOR}
    docker push grufos/postgres:${VERSION}.${MINOR}
fi

# pganalyze
echo "========="
echo "pganalyze"
echo "========="
if ! docker image ls | grep "grufos/pganalyze" ; then
    echo "    push ..."
    docker tag ${VERSION}_analyze:latest grufos/pganalyze:latest
#    docker push grufos/pganalyze:latest
    docker tag grufos/pganalyze:latest grufos/pganalyze:${VERSION}.${MINOR}
    docker push grufos/pganalyze:${VERSION}.${MINOR}
fi

# pgprobackup
echo "==========="
echo "pgprobackup"
echo "==========="
if ! docker image ls | grep "grufos/pgprobackup" ; then
    echo "    push ..."
    docker tag ${VERSION}_pgprobackup_backup:latest grufos/pgprobackup:latest
#    docker push grufos/pgprobackup:latest
    docker tag grufos/pgprobackup:latest grufos/pgprobackup:${VERSION}.${MINOR}_2.5.12
    docker push grufos/pgprobackup:${VERSION}.${MINOR}_2.5.12
fi

# pgprorestore
echo "============"
echo "pgprorestore"
echo "============"
if ! docker image ls | grep "grufos/pgprorestore" ; then
    echo "    push ..."
    docker tag ${VERSION}_pgprobackup_restore:latest grufos/pgprorestore:latest
#    docker push grufos/pgprorestore:latest
    docker tag grufos/pgprorestore:latest grufos/pgprorestore:${VERSION}.${MINOR}_2.5.12
    docker push grufos/pgprorestore:${VERSION}.${MINOR}_2.5.12
fi

# mamonsu
echo "======="
echo "mamonsu"
echo "======="
if ! docker image ls | grep "grufos/mamonsu" ; then
    echo "    push ..."
    docker tag ${VERSION}_mamonsu:latest grufos/mamonsu:latest
#    docker push grufos/mamonsu:latest
    docker tag grufos/mamonsu:latest grufos/mamonsu:${VERSION}_3.5.5
    docker push grufos/mamonsu:${VERSION}_3.5.5
fi
