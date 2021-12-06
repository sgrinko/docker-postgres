#!/bin/bash
clear
rm -rf /var/log/pgbouncer/*
rm -rf /var/log/postgresql/*
rm -rf /var/log/mamonsu/*
docker-compose -f "postgres-service_all.yml" up --build "$@"
