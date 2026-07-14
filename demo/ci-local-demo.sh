#!/bin/bash
set -e

echo "### docker network create ###"
docker network create taskapp-net || true

echo "### docker run mysql ###"
docker rm -f mysql-db >/dev/null 2>&1 || true
docker run -d --name mysql-db --network taskapp-net \
  -e MYSQL_ROOT_PASSWORD=rootpass -e MYSQL_DATABASE=taskdb \
  -e MYSQL_USER=taskuser -e MYSQL_PASSWORD=taskpass mysql:8.4

echo "### waiting for mysql to be ready ###"
READY=0
for i in $(seq 1 60); do
  if docker exec mysql-db mysql -uroot -prootpass -e "SELECT 1" >/dev/null 2>&1; then
    READY=$((READY + 1))
    [ "$READY" -ge 3 ] && break
  else
    READY=0
  fi
  sleep 1
done
echo "mysql ready"

echo "### docker run app ###"
docker rm -f task-app >/dev/null 2>&1 || true
docker run -d --name task-app --network taskapp-net -p 8080:8080 \
  -e DB_HOST=mysql-db -e DB_NAME=taskdb -e DB_USER=taskuser -e DB_PASSWORD=taskpass \
  docker-assignment-app:local

echo "### docker ps (list running containers) ###"
docker ps

echo "### waiting for app health ###"
for i in $(seq 1 30); do
  curl -sf http://localhost:8080/actuator/health | grep -q '"status":"UP"' && break
  sleep 2
done
curl -sf http://localhost:8080/actuator/health
echo ""

echo "### docker logs task-app ###"
docker logs task-app --tail 30

echo "### docker inspect task-app ###"
docker inspect task-app --format 'State={{.State.Status}} Health={{.State.Health.Status}} IP={{(index .NetworkSettings.Networks "taskapp-net").IPAddress}}'

echo "### docker stop task-app ###"
docker stop task-app

echo "### docker ps -a (all containers, including stopped) ###"
docker ps -a

echo "### docker start task-app ###"
docker start task-app

echo "### waiting for app health after restart ###"
for i in $(seq 1 30); do
  curl -sf http://localhost:8080/actuator/health | grep -q '"status":"UP"' && break
  sleep 2
done
curl -sf http://localhost:8080/actuator/health
echo ""

echo "### docker rm -f task-app (remove) ###"
docker rm -f task-app

echo "### cleanup mysql-db ###"
docker rm -f mysql-db
docker network rm taskapp-net

echo "### DONE: single-container lifecycle demo complete ###"
