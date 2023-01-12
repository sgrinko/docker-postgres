#!/bin/bash
docker run --rm --name upgrade-db --shm-size 2147483648 \
       -v "/var/lib/pgsql/15_1:/var/lib/postgresql" \
       -v "/var/log/postgresql1:/var/log/postgresql" \
       -v "/usr/share/postgres/14/tsearch_data:/usr/share/postgresql/14/tsearch_data" \
       -v "/usr/share/postgres/15/tsearch_data:/usr/share/postgresql/15/tsearch_data" \
       15_pgupgrade
