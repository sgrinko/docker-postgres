#!/bin/bash
clear
docker-compose -f "show_backup-service.yml" up --build "$@"
