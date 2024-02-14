#!/bin/bash
docker run --rm --name upgrade-db --shm-size 2147483648 \
       -v /var/lib/pgsql/16_1:/var/lib/postgresql \
       -v /var/log/postgresql1:/var/log/postgresql \
       -v /usr/share/postgres/15/tsearch_data:/usr/share/postgresql/15/tsearch_data \
       -v /usr/share/postgres/16/tsearch_data:/usr/share/postgresql/16/tsearch_data \
       -e PGDATACOPY_MODE=HardLink \
       16_pgupgrade
