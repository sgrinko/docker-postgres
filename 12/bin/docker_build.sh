#!/bin/bash
VERSION=12

set -euo pipefail

cd docker-pgbouncer
docker build . -t ${VERSION}_pgbouncer:latest
cd ..

cd docker-analyze
docker build . -t ${VERSION}_analyze:latest
cd ..

cd docker-mamonsu
docker build . -t ${VERSION}_mamonsu:latest
cd ..

cd docker-pgprobackup
docker build . -t ${VERSION}_pgprobackup_backup:latest
cd ..

cd docker-pgprorestore
docker build . -t ${VERSION}_pgprobackup_restore:latest
cd ..

cd docker-postgres
docker build . -t ${VERSION}_postgres:latest
cd ..

docker image ls
