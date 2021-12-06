#!/bin/bash
clear
docker-compose -f "check_cluster_service.yml" up --build "$@"
