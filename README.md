# Workshop Organizer + Olympic Games Starter (Docker)

## Installation
In a terminal run the following commands:
```
- cp .env.example .env
```

Change the following in your new .env file:

- POSTGRES_USER
- POSTGRES_PASSWORD
- BACKEND_PORT (if used / will not start)
- FRONTEND_PORT (if used / will not start)

then commands:
make all

## Tests

The tests run inside the Docker images, nothing else is needed on the host:

```
make test            # backend + frontend
make test-backend
make test-frontend
```

`make test` calls `scripts/run-tests.sh`. JUnit reports are written to `reports/<app>/`, even when a test fails.
A failing test also stops `make build`: no image is created.

## CI/CD (GitHub Actions)

- `.github/workflows/docker-ci.yml`: reusable pipeline (`workflow_call`) that runs `scripts/run-tests.sh <app>`, publishes the JUnit results and pushes the image to GHCR.
- `.github/workflows/backend.yml` / `frontend.yml`: call it when their folder changes.

| Event          | Tests | Image pushed to `ghcr.io/<owner>/<image>`        |
|----------------|-------|--------------------------------------------------|
| Pull request   | yes   | no                                               |
| Push on `main` | yes   | `latest`, `sha-<commit>`                         |
| Tag `v1.2.3`   | yes   | `1.2.3`, `1.2`, `sha-<commit>`                   |
