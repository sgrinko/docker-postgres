#!/bin/bash
clear
docker-compose -f "testconnect-service.yml" up --build "$@"
