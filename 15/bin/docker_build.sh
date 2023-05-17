#!/bin/bash
VERSION=15

set -euo pipefail

cd docker-pgbouncer
dir=`pwd`
echo ""
echo "====================================="
echo " $dir"
echo "====================================="
echo ""
docker build . -t ${VERSION}_pgbouncer:latest
cd ..

cd docker-analyze
dir=`pwd`
echo ""
echo "====================================="
echo " $dir"
echo "====================================="
echo ""
docker build . -t ${VERSION}_analyze:latest
cd ..

cd docker-mamonsu
dir=`pwd`
echo ""
echo "====================================="
echo " $dir"
echo "====================================="
echo ""
docker build . -t ${VERSION}_mamonsu:latest
cd ..

cd docker-pgprobackup
dir=`pwd`
echo ""
echo "====================================="
echo " $dir"
echo "====================================="
echo ""
docker build . -t ${VERSION}_pgprobackup_backup:latest
cd ..

cd docker-pgprorestore
dir=`pwd`
echo ""
echo "====================================="
echo " $dir"
echo "====================================="
echo ""
docker build . -t ${VERSION}_pgprobackup_restore:latest
cd ..

cd docker-pgupgrade
dir=`pwd`
echo ""
echo "====================================="
echo " $dir"
echo "====================================="
echo ""
docker build . -t ${VERSION}_pgupgrade:latest
cd ..

cd docker-postgres
dir=`pwd`
echo ""
echo "====================================="
echo " $dir"
echo "====================================="
echo ""
docker build . -t ${VERSION}_postgres:latest
cd ..

docker image ls
