#!/bin/bash
clear
rm -rf /var/log/postgresql/*
docker-compose -f "postgres-service.yml" up --build "$@"
