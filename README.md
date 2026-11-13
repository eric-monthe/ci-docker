# Workshop Organizer + Olympic Games Starter

- **Backend:** Spring Boot REST API (Java 21).
- **Frontend:** Angular app served by nginx.
- **Database:** PostgreSQL, with a daily backup.

Everything is built, tested and run in Docker.

## Requirements

- Docker with Compose v2
- `make`

You don't need Java, Node or PostgreSQL on your machine.

## Installation

```bash
cp .env.example .env
```

Edit `.env` and set at least:

| Variable                         | Description                           |
|----------------------------------|---------------------------------------|
| `POSTGRES_USER`                  | database user                         |
| `POSTGRES_PASSWORD`              | database password                     |
| `BACKEND_PORT` / `FRONTEND_PORT` | change them if 8080 / 80 are in use   |

Then build, test and start everything:

```bash
make
```

| Service  | URL                                                    |
|----------|--------------------------------------------------------|
| Frontend | http://localhost                                       |
| Backend  | http://localhost:8080/api/workshops                    |
| API docs | http://localhost:8080 (Swagger UI)                     |

## Testing

```bash
make test             # backend + frontend
make test-backend
make test-frontend
```

- JUnit reports are written to `reports/<app>/`, even when a test fails.
- A failing test also stops `make build`, so no image is created.

## Deploy

| Command                         | Description                                          |
|---------------------------------|------------------------------------------------------|
| `make`                          | build + test, then start                             |
| `make build`                    | build + test only                                    |
| `make up` / `make down`         | start / stop                                         |
| `make logs` / `make ps`         | follow logs / show status                            |
| `make backup`                   | back up the database now (`./backups`)               |
| `make restore FILE=backups/...` | restore a backup                                     |
| `make clean`                    | stop and remove build outputs (data is kept)         |

### From the registry (GHCR)

To run the images built by CI instead of building locally, point `.env` at the registry:

```bash
BACKEND_IMAGE=ghcr.io/eric-monthe/workshop-organizer:latest
FRONTEND_IMAGE=ghcr.io/eric-monthe/olympic-games-starter:latest
```

Then pull and start:

```bash
docker compose pull && make up
```

## CI/CD

GitHub Actions run the same tests in Docker (`scripts/run-tests.sh`), then push the images to GHCR.

| Event          | Tests | Image tags pushed              |
|----------------|-------|--------------------------------|
| Pull request   | yes   | none                           |
| Push on `main` | yes   | `latest`, `sha-<commit>`       |
| Tag `v1.2.3`   | yes   | `1.2.3`, `1.2`, `sha-<commit>` |

- A workflow only runs when its app changes. Changes to `.md` files don't trigger any run.
- To release a version: `git tag v1.0.0 && git push origin v1.0.0`
