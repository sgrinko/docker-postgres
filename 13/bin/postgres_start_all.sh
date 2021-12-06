#!/bin/bash
clear
rm -rf /var/log/pgbouncer1/*
rm -rf /var/log/postgresql1/*
rm -rf /var/log/mamonsu1/*
docker-compose -f "postgres-service_all.yml" up --build "$@"
