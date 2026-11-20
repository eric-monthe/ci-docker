# Operations Manual

## Table of contents

- [1. Installation guide](#1-installation-guide)
  - [1.1 System requirements](#11-system-requirements)
  - [1.2 Installing the front-end (Olympic Participation Tracker)](#12-installing-the-front-end-olympic-participation-tracker)
  - [1.3 Installing the back-end (Workshop Organizer API)](#13-installing-the-back-end-workshop-organizer-api)
  - [1.4 Checking the installation](#14-checking-the-installation)
  - [1.5 Troubleshooting](#15-troubleshooting)
- [2. Data backup plan](#2-data-backup-plan)
  - [2.1 Data to back up](#21-data-to-back-up)
  - [2.2 Backup strategy](#22-backup-strategy)
  - [2.3 Backup procedure](#23-backup-procedure)
  - [2.4 Restore procedure](#24-restore-procedure)
  - [2.5 Restore tests](#25-restore-tests)
- [3. Monitoring](#3-monitoring)
  - [3.1 Metrics to monitor](#31-metrics-to-monitor)
  - [3.2 Alert thresholds](#32-alert-thresholds)
  - [3.3 Healthchecks](#33-healthchecks)
  - [3.4 Log management](#34-log-management)
  - [3.5 Alerts and escalation](#35-alerts-and-escalation)
- [Notes and references](#notes-and-references)

## 1. Installation guide

The whole stack runs in Docker: no Java, Node or PostgreSQL is needed on the host. The repository holds both applications, `docker-compose.yml`, a `makefile` and the scripts.

| Compose service | Image | Role | Host port |
|---|---|---|---|
| `frontend` | `olympic-games-starter:1.0.0` (nginx 1.27-alpine) | Angular 20.3.7 front-end | 80 |
| `app` | `workshop-organizer:1.0.0` (eclipse-temurin 21-jre-alpine) | Spring Boot 3.2.4 API | 8080 |
| `db` | `postgres:13` | Database | not exposed |
| `backup` | `offen/docker-volume-backup:v2` | Scheduled backups | not exposed |

### 1.1 System requirements

| Item | Minimum / value |
|---|---|
| OS | Linux (Debian/Ubuntu recommended), macOS, or Windows 10/11 with WSL2 |
| Docker Engine | ≥ 24 with BuildKit / buildx (required for `RUN --mount=type=cache` and `--output`) |
| Docker Compose | v2 (`docker compose` plugin), ≥ 2.20 |
| Tools | `git`, `make` (GNU Make), `curl`, `tar` |
| Java / Node | Not needed on the host (Java 21 and Node 22 are in the build images) |
| CPU / RAM | 2 vCPU, 4 GB RAM (total Compose limits: 3 CPU, 1.66 GB) |
| Disk | 10 GB free (images + `db-data` volume + `backups/`) |
| Ports to free | 80 (front-end), 8080 (API); change with `FRONTEND_PORT` / `BACKEND_PORT` |
| Outbound network | Access to Docker Hub, Maven Central, npm registry (build) or ghcr.io (prebuilt images) |

Installing Docker on Debian: `sudo scripts/install/docker-linux.sh` (installs docker-ce, docker-buildx-plugin, docker-compose-plugin).

```bash
docker --version && docker compose version && docker buildx version
```

### 1.2 Installing the front-end (Olympic Participation Tracker)

1. Clone the repository and create the environment file:

```bash
git clone <repo-url> ci-cd-docker && cd ci-cd-docker
cp .env.example .env
```

2. Check `.env`: `FRONTEND_IMAGE=olympic-games-starter:1.0.0`, `FRONTEND_PORT=80`. No other variable is needed, because the front-end reads a static JSON file.

3. Build. This first runs the Karma tests (`npm ci` + `npm test`), then `ng build`, then builds the nginx image:

```bash
make build-frontend
```

4. Start:

```bash
docker compose up -d frontend
```

5. Check:

```bash
curl -I http://localhost/          # HTTP/1.1 200 OK
```

Alternative without building (image published by CI): in `.env`, set `FRONTEND_IMAGE=ghcr.io/eric-monthe/olympic-games-starter:latest`, then run `docker compose pull frontend && docker compose up -d frontend`.

### 1.3 Installing the back-end (Workshop Organizer API)

1. In `.env`, set the database credentials. Always change the password:

```bash
POSTGRES_DB=workshopsdb
POSTGRES_USER=workshops_user
POSTGRES_PASSWORD=<strong-password>
```

Compose passes them to the app as `SPRING_DATASOURCE_URL=jdbc:postgresql://db:5432/${POSTGRES_DB}`, `SPRING_DATASOURCE_USERNAME` and `SPRING_DATASOURCE_PASSWORD`.

2. Build. Gradle 8.7 runs the JUnit tests, then `bootWar`, then the non-root Java 21 runtime image:

```bash
make build-backend
```

3. Start PostgreSQL, then the API. `app` waits for `db` to be `healthy` (`pg_isready`):

```bash
docker compose up -d db backup
docker compose ps db               # STATUS: healthy
docker compose up -d app
```

The schema (`notion_model`, `workshop_model`, `workshop_model_notions`) is created at startup by Hibernate (`ddl-auto=update`).

4. Check:

```bash
curl http://localhost:8080/api/workshops     # [] or the JSON list
docker compose logs app | grep "Started"    # Started ...Application in X seconds
```

Shortcut to install everything: `make` (= `make build` + `make up`).

### 1.4 Checking the installation

```bash
make ps                                       # 4 services Up, db (healthy)
curl -I http://localhost/                     # front-end: 200
curl http://localhost:8080/api/notions        # API: 200
curl -X POST http://localhost:8080/api/notions -H 'Content-Type: application/json' -d '{"name":"Docker"}'
curl -X POST http://localhost:8080/api/workshops -H 'Content-Type: application/json' -d '{"name":"Workshop 1","notions":[{"name":"Docker"}]}'
docker compose exec db sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "select * from workshop_model;"'
docker compose restart app && curl http://localhost:8080/api/workshops   # data still there
make logs                                     # logs from all services
```

Swagger UI: http://localhost:8080/ . Front-end: http://localhost/ ("5 data loaded").

### 1.5 Troubleshooting

| Error / symptom | Cause | Fix |
|---|---|---|
| `.env not found. Run: cp .env.example .env` | `.env` file missing | `cp .env.example .env`, then edit it |
| `Bind for 0.0.0.0:80 failed: port is already allocated` | Port in use | `sudo lsof -i :80`; stop the other service or change `FRONTEND_PORT` / `BACKEND_PORT` |
| `permission denied while trying to connect to the Docker daemon socket` | User not in the docker group | `sudo usermod -aG docker $USER`, then log in again |
| `the --mount option requires BuildKit` | BuildKit missing | Install `docker-buildx-plugin` or `export DOCKER_BUILDKIT=1` |
| `dependency failed to start: container db is unhealthy` | PostgreSQL does not start (corrupted volume, RAM) | `docker compose logs db`; check RAM; as a last resort `docker compose down -v` (deletes the data) |
| `FATAL: password authentication failed for user` | Password changed after the volume was initialized | Restore the old password, or restore a backup into a new volume |
| `Connection to db:5432 refused` in the app logs | App started outside Compose / wrong network | Start with `docker compose up -d` (`backend-net` network) |
| Build stops, no image created | Tests failing (`test-exit-code` ≠ 0) | `make test-<app>`, then read `reports/<app>/*.xml` |
| `app` container restarts in a loop (`Exited (137)`) | OOM: 768M limit reached | `docker stats`; raise the `memory` limit |
| `npm ci` / Gradle timeout during build | Network or proxy | Retry; configure the Docker proxy; use the GHCR images |

## 2. Data backup plan

Backups are automated by the `backup` service (`offen/docker-volume-backup:v2`). Before each archive, it runs `pg_dump` inside the `db` container (label `docker-volume-backup.archive-pre`).

### 2.1 Data to back up

| Data | Location | Why |
|---|---|---|
| PostgreSQL database (schema + data) | `db-data` volume → SQL dump in `db-dumps:/tmp/dumps/dump.sql` | The only business data (notions, workshops). A logical dump is consistent and portable, unlike a live copy of the files |
| `.env` file | repository root (ignored by Git) | Holds the credentials; without it you cannot reconnect to the database |
| Configuration | `docker-compose.yml`, `makefile`, `nginx/nginx.conf`, `application.properties` | Already versioned in Git (the repository is the backup) |
| Application images | ghcr.io (`x.y.z`, `sha-*` tags) | Allow redeploying an exact version |
| Logs | json-file driver (10m × 3) | Not backed up: short-term troubleshooting only |

### 2.2 Backup strategy

| Data | Frequency | Type | Retention | Storage |
|---|---|---|---|---|
| PostgreSQL dump | Daily, 02:00 (`BACKUP_CRON_EXPRESSION=0 2 * * *`) | Full (pg_dump --clean) | 7 days (`BACKUP_RETENTION_DAYS=7`) | Local: `./backups/backup-YYYY-MM-DDTHH-MM-SS.tar.gz` |
| PostgreSQL dump (recommended) | Weekly | Full | 4 weeks + 12 monthly | Remote: S3 / object storage (offen supports `AWS_S3_BUCKET_NAME`) |
| Manual dump | Before each upgrade / migration | Full | Until the release is validated | Local `./backups` |
| `.env` (recommended) | On every change | Full | Permanent | Today: only on the server. Should be stored in a secrets vault (e.g. HashiCorp Vault, Bitwarden) |
| Configuration | On every commit | Git | Full history | GitHub |

The database is a few MB, so a daily full backup is enough: incremental backups would add complexity for no real gain. Follow the 3-2-1 rule: the remote copy is recommended, because today everything sits on the same host.

### 2.3 Backup procedure

**Automatic:** the `backup` container runs all the time and applies the cron schedule. Archives older than 7 days are pruned automatically (`BACKUP_PRUNING_PREFIX=backup-`).

**Manual:**

```bash
make backup
```

What the command does:

```bash
docker compose exec backup backup
  └─ (in db) pg_dump --clean --if-exists -U $POSTGRES_USER -d $POSTGRES_DB > /tmp/dumps/dump.sql
  └─ archive /backup/db-dumps → ./backups/backup-2026-11-20T02-00-00.tar.gz
```

Check the archive:

```bash
ls -lh backups/ && tar -tzf backups/backup-<date>.tar.gz     # /backup/db-dumps/dump.sql
```

Without the offen service (direct dump):

```bash
docker compose exec -T db sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB"' | gzip > backups/manual-$(date +%F).sql.gz
```

Back up the configuration:

```bash
tar -czf config-$(date +%F).tar.gz .env docker-compose.yml makefile   # store off the server
```

### 2.4 Restore procedure

1. Pick the archive: `ls -1t backups/`.

2. Stop the API so nothing writes during the restore:

```bash
docker compose stop app
```

3. Restore. The dump contains `DROP ... IF EXISTS`, so it replaces the tables:

```bash
make restore FILE=backups/backup-2026-11-20T02-00-00.tar.gz
# = tar -xOzf FILE /backup/db-dumps/dump.sql | docker compose exec -T db psql -q -U $POSTGRES_USER -d $POSTGRES_DB
```

4. Restart and check:

```bash
docker compose start app
curl http://localhost:8080/api/workshops
docker compose exec db sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "select count(*) from workshop_model;"'
```

**Volume completely lost:** `docker compose up -d db`, wait for `healthy`, then `make restore FILE=...`. Postgres recreates the empty database from `.env`, and the dump fills it.

Procedure tested with `backups/backup-2026-11-04T16-42-53.tar.gz` (4.5 KB dump).

### 2.5 Restore tests

- **Frequency:** monthly, and after any change to the procedure or to the PostgreSQL version.
- **Environment:** an isolated stack on the same host or on a test VM, without touching production:

```bash
docker compose -p restore-test up -d db
tar -xOzf backups/<archive>.tar.gz /backup/db-dumps/dump.sql | docker compose -p restore-test exec -T db sh -c 'psql -q -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
docker compose -p restore-test down -v
```

- **Success criteria:** `psql` returns no error; the row counts of `notion_model`, `workshop_model` and `workshop_model_notions` match production at dump time; the API starts on the restored database and `GET /api/workshops` returns the data.
- **Record keeping:** for each test, log the date, archive tested, duration, result and operator in a register (wiki or ticket).

## 3. Monitoring

**Current state:** PostgreSQL healthcheck, CPU/RAM limits, capped logs, `restart: unless-stopped`. Everything else is **recommended**.

### 3.1 Metrics to monitor

| Metric | Service | Why |
|---|---|---|
| CPU % | all | Saturation = slowness; limits 1 / 1 / 0.5 / 0.5 CPU |
| Memory vs limit | app (768M), db (512M), front (128M) | Going over the limit = OOM kill + restart |
| Free disk space | host (Docker volumes, `backups/`) | PostgreSQL stops when the disk is full |
| Network in/out | app, frontend | Spots abnormal traffic spikes |
| Response time p95 | app (`/api/*`) | User-perceived quality |
| Requests / s | app, frontend | Capacity planning |
| 5xx error rate | app, nginx | Application malfunction |
| Active PostgreSQL connections | db | HikariCP pool (10 by default); saturation = timeouts |
| Container status / restarts | all | A container restarting in a loop hides an outage |
| Age of the last backup | backup | Backup silently failing |

### 3.2 Alert thresholds

| Metric | Warning | Critical | Action |
|---|---|---|---|
| Container CPU | > 70% for 5 min | > 90% for 5 min | Analyse requests; raise the limit / scale the app |
| Container memory | > 80% of the limit | > 95% of the limit | Analyse the heap; raise `memory` |
| Host disk | > 80% | > 90% | Prune images (`docker image prune`), move backups |
| Response time p95 | > 300 ms | > 1 s | Analyse SQL logs and indexes |
| 5xx error rate | > 1% | > 5% | Read app logs; roll back to the previous image |
| DB connections | > 80% of the pool | pool exhausted | Look for leaks; tune HikariCP |
| Healthcheck | 1 failure | 3 consecutive failures | Restart the service; escalate |
| Container restarts | ≥ 1 / h | ≥ 3 / h | Read logs; check for OOM (`docker inspect`) |
| Last backup | > 26 h | > 48 h | `docker compose logs backup`; run `make backup` |

### 3.3 Healthchecks

| Service | Command | How to read it |
|---|---|---|
| db (configured) | `docker compose exec db pg_isready -U workshops_user -d workshopsdb` | `accepting connections` = OK; Compose: interval 5s, timeout 5s, 10 retries |
| app | `curl -fs http://localhost:8080/api/workshops` | 200 + JSON = API and database OK |
| app (recommended) | add `spring-boot-starter-actuator`, then `curl http://localhost:8080/actuator/health` | `{"status":"UP"}` (includes the database) |
| frontend | `curl -I http://localhost/` | `200 OK` |
| Containers | `docker compose ps` / `docker ps` | `Up`, `(healthy)`; `Restarting` = problem |
| Resources | `docker stats --no-stream` | CPU %, MEM USAGE / LIMIT |

Recommended Compose healthchecks (busybox `wget` is available in the alpine images):

```bash
app:      test: ["CMD-SHELL", "wget -qO- http://localhost:8080/actuator/health || exit 1"]
frontend: test: ["CMD-SHELL", "wget -q --spider http://localhost/ || exit 1"]
```

### 3.4 Log management

- **Location:** container standard output, stored by Docker (`json-file` driver) in `/var/lib/docker/containers/<id>/<id>-json.log`.
- **Rotation:** `max-size: 10m`, `max-file: 3` on every service (`x-logging` anchor), so 30 MB max per container.
- **Levels:** Spring Boot logs at INFO by default. `spring.jpa.show-sql=true` prints every SQL query: set it to `false` in production. nginx writes access and error logs to stdout and stderr.

```bash
make logs                               # all services, live
docker compose logs -f --tail=100 app   # API
docker compose logs --since 1h db       # PostgreSQL, last hour
docker compose logs backup              # backup results
```

- **Recommended:** centralize with Loki + Promtail (or ELK), with 30-day retention.

### 3.5 Alerts and escalation

**Not in place today.** Nothing sends alerts yet; the setup below is what should be put in place before production.

**Recommended tooling:** Prometheus + cAdvisor (container metrics) + postgres_exporter + Grafana (dashboards, alerting), or Uptime Kuma as a lightweight option (HTTP probes and notifications).

Recommended channels and response times:

| Severity | Channel | Recipients | Response time |
|---|---|---|---|
| Warning | Slack `#ops-alerts` + email | Dev team | 4 business hours |
| Critical | Slack + SMS / call (PagerDuty or Opsgenie) | On-call Dev + Ops | 15 min |

**Recommended escalation if an alert is not acknowledged:**

- Level 1, on-call Dev: takes ownership within 15 min (critical).
- Level 2, Ops / tech lead: if not acknowledged after 30 min, or not resolved after 1 h.
- Level 3, Manager: if the outage lasts more than 2 h or data loss is at risk. Decides on communication and a possible rollback.

Emergency contacts: should be kept in a single shared place (e.g. the team wiki) with name, phone and on-call slot.

## Notes and references

- Docker Compose: https://docs.docker.com/compose/
- Docker json-file logging: https://docs.docker.com/engine/logging/drivers/json-file/
- PostgreSQL 13 pg_dump / pg_isready: https://www.postgresql.org/docs/13/app-pgdump.html
- offen/docker-volume-backup: https://offen.github.io/docker-volume-backup/
- Spring Boot Actuator: https://docs.spring.io/spring-boot/reference/actuator/
- Prometheus / Grafana / cAdvisor: https://prometheus.io/docs/ , https://grafana.com/docs/ , https://github.com/google/cadvisor

**Technical choices:**

- **Everything in Docker:** one prerequisite (Docker), the same environment in dev, CI and operations.
- **Blocking tests in the Dockerfile:** a broken image cannot be built or published.
- **Explicit version tags** (`1.0.0`, semver from CI) rather than `latest`, so you can roll back.
- **Network isolation:** `db` is reachable only through `backend-net`, and the front-end is on `frontend-net`.
- **offen/docker-volume-backup:** cron, retention and pruning without a custom script; it can also push to S3.

**Watch points:** `postgres:13` has been out of support since November 2025 (plan a move to 16 or 17 via dump/restore); the schema is managed by `ddl-auto=update` (plan Flyway); the API has no authentication.
