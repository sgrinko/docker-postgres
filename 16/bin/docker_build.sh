#!/bin/bash
#
# получает через пробел имена контейнеров для сборки. Если не указано, то принимается такая строка:
# pgbouncer postgres pgupgrade analyze mamonsu pgprobackup pgprorestore pgprocheckdb
#
VERSION=16

set -euo pipefail

if [[ $# -ne 0 ]]; then
    LISTDOCKER=$@
else
    LISTDOCKER="pgbouncer postgres pgupgrade analyze mamonsu pgprobackup pgprorestore pgprocheckdb"
fi

for param in $LISTDOCKER
do
    cd docker-$param
    dir=`pwd`
    echo ""
    echo "====================================="
    echo " $dir"
    echo "====================================="
    echo ""
    docker build --no-cache . -t ${VERSION}_$param:latest
    cd ..
done

docker image ls --all
