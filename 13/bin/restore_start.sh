#!/bin/bash
clear
docker-compose -f "restore-service.yml" up --build "$@"
