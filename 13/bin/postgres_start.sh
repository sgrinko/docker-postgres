#!/bin/bash
clear
rm -rf /var/log/postgresql1/*
docker-compose -f "postgres-service.yml" up --build "$@"
