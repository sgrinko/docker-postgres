#!/bin/bash
# docker system prune -a    # чистка всех образов в каталоге /var/lib/docker/overlay2
docker stop $(docker ps -q)
docker rm -v $(docker ps -aq -f status=exited)
docker rmi $(docker image ls -q) -f
docker rmi $(docker image ls -q) -f
