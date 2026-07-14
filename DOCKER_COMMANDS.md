# Docker & Docker Compose - Setup and Command Reference

This documents how Docker was set up on this machine and every category of
Docker command used in this project, with what each one does and why. Meant
to be read through or demoed live, command by command.

## 1. Setup

Docker Engine + Docker Compose were installed via **WSL2** (Windows
Subsystem for Linux), running inside an Ubuntu distro:

```bash
wsl --install                      # installs WSL2 + a default Linux distro
# inside the Ubuntu distro:
curl -fsSL https://get.docker.com | sh   # installs Docker Engine + CLI + Compose plugin
```

Verify the installation:

```bash
docker --version
# Docker version 29.6.1, build 8900f1d

docker compose version
# Docker Compose version v5.3.1
```

Both are well above the assignment's minimums (Docker 20.10+, Compose 1.29+).

Verify the daemon actually works end-to-end by running a real container:

```bash
docker run --rm hello-world
```
This pulls the `hello-world` image from Docker Hub, runs it, prints a
confirmation message, and exits - proving the client can talk to the daemon,
pull from a registry, and run a container.

## 2. Image commands

| Command | What it does |
|---|---|
| `docker build -t <name>:<tag> <path>` | Builds an image from a Dockerfile in `<path>`, tagging it `<name>:<tag>` |
| `docker images` | Lists all images stored locally, with size and creation date |
| `docker image inspect <image>` | Full JSON metadata for an image (layers, env, entrypoint, size) |
| `docker rmi <image>` | Deletes a local image (fails if a container is still using it) |
| `docker tag <src> <dst>` | Gives an existing image an additional name/tag, e.g. before pushing to a registry |

Example used in this project:
```bash
cd app
docker build -t docker-assignment-app:local .
docker images | grep docker-assignment-app
```

## 3. Container lifecycle commands

| Command | What it does |
|---|---|
| `docker run -d --name <n> -p 8080:8080 <image>` | Creates and starts a new container in the background (`-d`), publishing port 8080 |
| `docker ps` | Lists **running** containers |
| `docker ps -a` | Lists **all** containers, including stopped/exited ones |
| `docker stop <name>` | Sends SIGTERM (graceful shutdown) to a running container |
| `docker start <name>` | Starts an existing (stopped) container back up |
| `docker restart <name>` | Stop + start in one step |
| `docker rm <name>` / `docker rm -f <name>` | Removes a container (`-f` forces removal even if running) |
| `docker exec -it <name> sh` | Opens an interactive shell inside a running container |

Example - the full lifecycle used to demo this project:
```bash
docker run -d --name task-app --network taskapp-net -p 8080:8080 \
  -e DB_HOST=mysql-db -e DB_NAME=taskdb -e DB_USER=taskuser -e DB_PASSWORD=taskpass \
  docker-assignment-app:local

docker ps                    # confirm it's running
docker stop task-app         # stop it
docker ps -a                 # confirm it shows "Exited"
docker start task-app        # bring it back
docker rm -f task-app        # remove it entirely
```

## 4. Inspecting containers & logs

| Command | What it does |
|---|---|
| `docker logs <name>` | Prints a container's stdout/stderr |
| `docker logs -f <name>` | Follows logs live (like `tail -f`) |
| `docker logs --tail 50 <name>` | Last 50 lines only |
| `docker inspect <name>` | Full JSON: network settings, mounts, env vars, health status, restart policy |
| `docker inspect <name> --format '{{.State.Health.Status}}'` | Pulls just one field out of that JSON (Go template) |
| `docker top <name>` | Lists processes running inside the container |
| `docker stats` | Live CPU/memory/network usage for all running containers |

Example:
```bash
docker logs task-app --tail 30
docker inspect task-app --format 'State={{.State.Status}} Health={{.State.Health.Status}}'
```

## 5. Docker Compose commands

| Command | What it does |
|---|---|
| `docker compose build` | Builds/rebuilds images for every service with a `build:` key |
| `docker compose up -d` | Creates and starts every service defined in `docker-compose.yml`, in the background |
| `docker compose ps` | Lists the status of every service in the current project |
| `docker compose logs <service>` | Logs for one service (or all, if omitted) |
| `docker compose exec <service> sh` | Shell into a running Compose-managed container |
| `docker compose down` | Stops and removes all containers + the project's network |
| `docker compose down -v` | Same, but also deletes named volumes (drops persisted data) |

Example - bringing up the full app + mysql + adminer stack:
```bash
docker compose build
docker compose up -d
docker compose ps
# NAME                        STATUS
# docker-assignment-app       Up (healthy)
# docker-assignment-mysql     Up (healthy)
# docker-assignment-adminer   Up
```

## 6. Network commands

| Command | What it does |
|---|---|
| `docker network create <name>` | Creates a user-defined bridge network |
| `docker network ls` | Lists all networks on the host |
| `docker network inspect <name>` | Shows subnet, gateway, and every container attached |
| `docker network connect <net> <container>` | Attaches a running container to an additional network |
| `docker network disconnect <net> <container>` | Detaches it |
| `docker network rm <name>` | Deletes an (unused) network |

Why it matters here: containers on the same user-defined network can resolve
each other **by container name** (e.g., the app connects to `mysql-db`, not
an IP address) - that's what makes `DB_HOST=mysql-db` work.

## 7. Volume commands

| Command | What it does |
|---|---|
| `docker volume create <name>` | Creates a named volume (managed by Docker, lives outside any container) |
| `docker volume ls` | Lists all volumes |
| `docker volume inspect <name>` | Shows the volume's actual location on disk and which containers use it |
| `docker volume rm <name>` | Deletes a volume (and the data in it) |
| `docker run -v <volume>:/path` | Mounts a named volume into a container at `/path` |
| `docker run -v /host/path:/container/path` | Bind-mounts a specific host file/folder into a container |

Why it matters: MySQL's data directory (`/var/lib/mysql`) is a named volume
(`mysql-data`), so `docker compose down` (without `-v`) keeps the database
contents even though the container itself is destroyed and recreated.

## 8. Registry (Docker Hub) commands

| Command | What it does |
|---|---|
| `docker login -u <user>` | Authenticates the CLI against Docker Hub (prompts for a password/token) |
| `docker tag <local> <user>/<repo>:<tag>` | Renames/tags a local image for a specific registry repo |
| `docker push <user>/<repo>:<tag>` | Uploads the image to Docker Hub |
| `docker pull <user>/<repo>:<tag>` | Downloads an image from Docker Hub |
| `docker logout` | Clears stored registry credentials |

Example - the actual push/pull round trip run for this project:
```bash
docker login -u biradarvijay
docker build -t biradarvijay/docker-assignment-app:latest ./app
docker push biradarvijay/docker-assignment-app:latest

docker rmi biradarvijay/docker-assignment-app:latest   # delete local copy
docker pull biradarvijay/docker-assignment-app:latest  # pull it back down
# digest after pull matched the digest that was pushed - proves it's a
# genuine round trip, not a cached local layer
```

## Where to see this run for real

- Live, on this machine: `demo/ci-local-demo.sh`, `demo/ci-compose-demo.sh`,
  `demo/ci-push-pull-demo.sh` in this repo run every command above against a
  real Docker daemon.
- Automated, in CI: `.github/workflows/docker-ci.yml` runs the same
  categories of commands on every push - see the Actions tab for the full
  logged output of each one.
