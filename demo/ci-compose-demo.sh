#!/bin/bash
set -e

echo "### docker compose build ###"
docker compose build

echo "### docker compose up -d ###"
docker compose up -d

echo "### docker compose ps (ensure all services running) ###"
docker compose ps

echo "### waiting for app health ###"
for i in $(seq 1 30); do
  curl -sf http://localhost:8080/actuator/health | grep -q '"status":"UP"' && break
  sleep 2
done
curl -sf http://localhost:8080/actuator/health
echo ""

echo "### create a task via the web UI form endpoint ###"
curl -s -X POST http://localhost:8080/tasks -d "title=Reviewer+demo+task" -d "description=Created+via+curl+during+live+demo" >/dev/null
curl -s http://localhost:8080/api/tasks
echo ""

echo "### docker compose logs (tail) ###"
docker compose logs --tail=20 app

echo "### docker compose down ###"
docker compose down

echo "### DONE: compose multi-container demo complete ###"
