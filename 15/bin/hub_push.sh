#!/bin/bash
VERSION=15
MINOR=6
VERS_BOUNCER="1.22.0"
VERS_PROBACKUP="2.5.13"
VERS_MAMONSU="3.5.5"
ACCOUNT=grufos
LATEST_PUSH='no'

set -euo pipefail

if [[ $# -ne 0 ]]; then
    LISTDOCKER=$@
else
    LISTDOCKER="pgbouncer postgres pgupgrade analyze mamonsu pgprobackup pgprorestore pgprocheckdb"
fi

for param in $LISTDOCKER
do
    if [ "$param" = "pgbouncer" ]; then
       vers="${VERS_BOUNCER}"
    elif [ "$param" = "mamonsu" ]; then
       vers="${VERSION}_${VERS_MAMONSU}"
    elif [[ "$param" = "pgprobackup" || $param = "pgprorestore" || $param = "pgprocheckdb" ]]; then
       vers="${VERSION}.${MINOR}_${VERS_PROBACKUP}"
    else
       vers="${VERSION}.${MINOR}"
    fi
    echo "======================="
    echo "${param} -> ${vers}"
    echo "======================="
    if ! docker image ls | grep "${ACCOUNT}/${param}" ; then
        echo "    push ..."
        docker tag ${VERSION}_${param}:latest ${ACCOUNT}/${param}:latest
        if [ "$LATEST_PUSH" = "yes" ]; then
            docker push ${ACCOUNT}/${param}:latest
        fi
        docker tag ${ACCOUNT}/${param}:latest ${ACCOUNT}/${param}:${vers}
        docker push ${ACCOUNT}/${param}:${vers}
    fi
done
