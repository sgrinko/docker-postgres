#!/bin/bash
VERSION=15
MINOR=4
PROJECT=dba_postgres
URL=harbor.company.ru

set -euo pipefail

# pgbouncer
echo "========="
echo "pgbouncer"
echo "========="
if ! docker image ls | grep "${URL}/${PROJECT}/pgbouncer" ; then
    echo "    push ..."
    docker tag ${VERSION}_pgbouncer:latest ${URL}/${PROJECT}/pgbouncer:latest
    docker push ${URL}/${PROJECT}/pgbouncer:latest
    docker tag ${URL}/${PROJECT}/pgbouncer:latest  ${URL}/${PROJECT}/pgbouncer:1.20.1
    docker push ${URL}/${PROJECT}/pgbouncer:1.20.1
fi

# postgres
echo "========"
echo "postgres"
echo "========"
if ! docker image ls | grep "${URL}/${PROJECT}/postgres" ; then
    echo "    push ..."
    docker tag ${VERSION}_postgres:latest ${URL}/${PROJECT}/postgres:latest
    docker push ${URL}/${PROJECT}/postgres:latest
    docker tag ${URL}/${PROJECT}/postgres:latest ${URL}/${PROJECT}/postgres:${VERSION}.${MINOR}
    docker push ${URL}/${PROJECT}/postgres:${VERSION}.${MINOR}
fi

# pgupgrade
echo "========="
echo "pgupgrade"
echo "========="
if ! docker image ls | grep "${URL}/${PROJECT}/pgupgrade" ; then
    echo "    push ..."
    docker tag ${VERSION}_pgupgrade:latest ${URL}/${PROJECT}/pgupgrade:latest
    docker push ${URL}/${PROJECT}/pgupgrade:latest
    docker tag ${URL}/${PROJECT}/pgupgrade:latest ${URL}/${PROJECT}/pgupgrade:${VERSION}.${MINOR}
    docker push ${URL}/${PROJECT}/pgupgrade:${VERSION}.${MINOR}
fi

# pganalyze
echo "========="
echo "pganalyze"
echo "========="
if ! docker image ls | grep "${URL}/${PROJECT}/pganalyze" ; then
    echo "    push ..."
    docker tag ${VERSION}_analyze:latest ${URL}/${PROJECT}/pganalyze:latest
    docker push ${URL}/${PROJECT}/pganalyze:latest
    docker tag ${URL}/${PROJECT}/pganalyze:latest ${URL}/${PROJECT}/pganalyze:${VERSION}.${MINOR}
    docker push ${URL}/${PROJECT}/pganalyze:${VERSION}.${MINOR}
fi

# pgprobackup
echo "==========="
echo "pgprobackup"
echo "==========="
if ! docker image ls | grep "${URL}/${PROJECT}/pgprobackup" ; then
    echo "    push ..."
    docker tag ${VERSION}_pgprobackup_backup:latest ${URL}/${PROJECT}/pgprobackup:latest
    docker push ${URL}/${PROJECT}/pgprobackup:latest
    docker tag ${URL}/${PROJECT}/pgprobackup:latest ${URL}/${PROJECT}/pgprobackup:${VERSION}.${MINOR}_2.5.12
    docker push ${URL}/${PROJECT}/pgprobackup:${VERSION}.${MINOR}_2.5.12
fi

# pgprorestore
echo "============"
echo "pgprorestore"
echo "============"
if ! docker image ls | grep "${URL}/${PROJECT}/pgprorestore" ; then
    echo "    push ..."
    docker tag ${VERSION}_pgprobackup_restore:latest ${URL}/${PROJECT}/pgprorestore:latest
    docker push ${URL}/${PROJECT}/pgprorestore:latest
    docker tag ${URL}/${PROJECT}/pgprorestore:latest ${URL}/${PROJECT}/pgprorestore:${VERSION}.${MINOR}_2.5.12
    docker push ${URL}/${PROJECT}/pgprorestore:${VERSION}.${MINOR}_2.5.12
fi

# mamonsu
echo "======="
echo "mamonsu"
echo "======="
if ! docker image ls | grep "${URL}/${PROJECT}/mamonsu" ; then
    echo "    push ..."
    docker tag ${VERSION}_mamonsu:latest ${URL}/${PROJECT}/mamonsu:latest
    docker push ${URL}/${PROJECT}/mamonsu:latest
    docker tag ${URL}/${PROJECT}/mamonsu:latest ${URL}/${PROJECT}/mamonsu:${VERSION}_3.5.5
    docker push ${URL}/${PROJECT}/mamonsu:${VERSION}_3.5.5
fi
