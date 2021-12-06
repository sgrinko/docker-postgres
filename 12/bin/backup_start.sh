#!/bin/bash
clear
docker-compose -f "backup-service.yml" up --build "$@"
