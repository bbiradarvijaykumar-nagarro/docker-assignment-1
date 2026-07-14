# Docker Assignment 1 - Task Manager

A small Spring Boot task manager backed by MySQL, containerized with Docker and
orchestrated with Docker Compose (app + MySQL + Adminer). Includes a GitHub
Actions pipeline that builds, runs, inspects, composes, and pushes/pulls the
image against Docker Hub.

## Stack

- Java 17, Spring Boot 3.3 (Web, Data JPA, Thymeleaf, Actuator)
- MySQL 8.4
- Adminer (DB admin UI)
- Docker / Docker Compose
- GitHub Actions

## Live local demo scripts

`demo/` has three scripts that exercise the full task checklist end-to-end
against a real local Docker daemon (used here via WSL2):

- `ci-local-demo.sh` - build the image, run it as a plain container next to
  MySQL, and walk through `docker ps`, `logs`, `inspect`, `stop`, `ps -a`,
  `start`, `rm`.
- `ci-compose-demo.sh` - `docker compose build/up/ps`, create a task through
  the running app, tail logs, `compose down`.
- `ci-push-pull-demo.sh` - push the image to Docker Hub, delete it locally,
  pull it back, and run the pulled image against a fresh MySQL to confirm
  the registry round trip. Needs `DOCKERHUB_TOKEN` in the environment.

## Project layout

```
app/                         Spring Boot application
  Dockerfile                 Multi-stage build (Maven -> JRE runtime)
  src/main/java/...          Application code
  src/main/resources/...     Config, Thymeleaf template, static CSS
docker-compose.yml           app + mysql + adminer services
.env.example                 Sample environment variables
.github/workflows/docker-ci.yml   CI/CD pipeline
```

## 1. Prerequisites

- Docker 20.10+ and Docker Compose 1.29+ (or the Docker Compose v2 plugin)
- Java 17 and Maven (only needed if you want to run/test outside Docker)
- A Docker Hub account (for the registry push/pull steps)

## 2. Verify your Docker installation

```bash
docker --version
docker compose version
docker run hello-world
```

## 3. Run the app locally (outside Docker, optional)

```bash
cd app
mvn test
mvn spring-boot:run
```
This uses the datasource in `application.properties`, defaulting to
`localhost:3306`, so you'll need a local MySQL instance or the Compose one
running first.

## 4. Build and run with plain Docker (single container)

```bash
cd app
docker build -t docker-assignment-app:local .

docker network create taskapp-net
docker run -d --name mysql-db --network taskapp-net \
  -e MYSQL_ROOT_PASSWORD=rootpass -e MYSQL_DATABASE=taskdb \
  -e MYSQL_USER=taskuser -e MYSQL_PASSWORD=taskpass mysql:8.4

docker run -d --name task-app --network taskapp-net -p 8080:8080 \
  -e DB_HOST=mysql-db -e DB_NAME=taskdb -e DB_USER=taskuser -e DB_PASSWORD=taskpass \
  docker-assignment-app:local
```

Useful Docker commands to manage it:

```bash
docker ps                 # list running containers
docker ps -a               # list all containers, including stopped
docker logs task-app       # view logs
docker inspect task-app    # inspect container details
docker stop task-app       # stop
docker start task-app      # start again
docker rm -f task-app      # remove
```

Visit http://localhost:8080.

## 5. Run the full stack with Docker Compose (multi-container)

```bash
cp .env.example .env
docker compose build
docker compose up -d
docker compose ps
docker compose logs -f app
docker compose down          # add -v to also drop the mysql volume
```

Services:
- App: http://localhost:8080
- Adminer (DB UI): http://localhost:8081 — server `mysql`, user/password from `.env`

## 6. Push to / pull from Docker Hub

```bash
docker login

docker build -t <your-dockerhub-username>/docker-assignment-app:latest ./app
docker push <your-dockerhub-username>/docker-assignment-app:latest

docker pull <your-dockerhub-username>/docker-assignment-app:latest
docker run -d -p 8080:8080 <your-dockerhub-username>/docker-assignment-app:latest
```

To use your own Docker Hub username with Compose, set `DOCKERHUB_USERNAME` in
`.env` (see `.env.example`) — the image tag in `docker-compose.yml` picks it up
automatically.

## 7. CI/CD pipeline

`.github/workflows/docker-ci.yml` runs on every push/PR to `main` and:

1. **build-and-test** — runs the Maven test suite (H2 in-memory DB) and packages the jar.
2. **single-container-lifecycle** — builds the image, runs the app + MySQL as
   plain Docker containers, and exercises `docker ps`, `logs`, `inspect`,
   `stop`, `start`, `rm`.
3. **compose-multi-container** — brings the whole stack up with
   `docker compose up -d`, verifies health, tears it down.
4. **push-and-pull** (main branch only) — builds, tags, pushes to Docker Hub,
   removes the local image, pulls it back down, and runs it via Compose to
   prove the round trip works.

To enable the push/pull job, add these repository secrets under
**Settings → Secrets and variables → Actions**:

| Secret              | Value                                   |
|---------------------|------------------------------------------|
| `DOCKERHUB_USERNAME` | your Docker Hub username                |
| `DOCKERHUB_TOKEN`    | a Docker Hub access token (not your password) |

## 8. API

| Method | Path              | Description        |
|--------|-------------------|---------------------|
| GET    | `/`               | Web UI (Thymeleaf)  |
| GET    | `/api/tasks`      | List tasks (JSON)   |
| GET    | `/api/tasks/{id}` | Get one task        |
| POST   | `/api/tasks`      | Create a task        |
| PUT    | `/api/tasks/{id}` | Update a task        |
| DELETE | `/api/tasks/{id}` | Delete a task        |
| GET    | `/actuator/health`| Health check         |

## Bonus: database integration

The app persists tasks in MySQL via Spring Data JPA (`Task` entity,
`TaskRepository`), configured entirely through environment variables so the
same image works against the Compose-managed `mysql` service, a plain
`docker run` MySQL container, or a local MySQL install.
