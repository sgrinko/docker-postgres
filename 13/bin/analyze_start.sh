#!/bin/bash
clear
docker-compose -f "analyze-service.yml" up --build "$@"
