#!/bin/bash
set -e

echo "### docker login ###"
echo "$DOCKERHUB_TOKEN" | docker login -u biradarvijay --password-stdin

echo "### docker build + tag ###"
docker build -t biradarvijay/docker-assignment-app:latest ./app

echo "### docker push ###"
docker push biradarvijay/docker-assignment-app:latest

echo "### remove local image to force a real pull ###"
docker rmi biradarvijay/docker-assignment-app:latest

echo "### docker pull ###"
docker pull biradarvijay/docker-assignment-app:latest

echo "### run pulled image against a fresh mysql and verify ###"
docker network create pull-demo-net || true
docker rm -f pull-demo-mysql pull-demo-app >/dev/null 2>&1 || true
docker run -d --name pull-demo-mysql --network pull-demo-net \
  -e MYSQL_ROOT_PASSWORD=rootpass -e MYSQL_DATABASE=taskdb \
  -e MYSQL_USER=taskuser -e MYSQL_PASSWORD=taskpass mysql:8.4

READY=0
for i in $(seq 1 60); do
  if docker exec pull-demo-mysql mysql -uroot -prootpass -e "SELECT 1" >/dev/null 2>&1; then
    READY=$((READY + 1))
    [ "$READY" -ge 3 ] && break
  else
    READY=0
  fi
  sleep 1
done

docker run -d --name pull-demo-app --network pull-demo-net -p 8090:8080 \
  -e DB_HOST=pull-demo-mysql -e DB_NAME=taskdb -e DB_USER=taskuser -e DB_PASSWORD=taskpass \
  biradarvijay/docker-assignment-app:latest

for i in $(seq 1 30); do
  curl -sf http://localhost:8090/actuator/health | grep -q '"status":"UP"' && break
  sleep 2
done
echo "### health check on the PULLED image ###"
curl -sf http://localhost:8090/actuator/health
echo ""

echo "### cleanup ###"
docker rm -f pull-demo-app pull-demo-mysql
docker network rm pull-demo-net
docker logout

echo "### DONE: push/pull registry round-trip complete ###"
