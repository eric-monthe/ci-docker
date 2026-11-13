# Everything runs in Docker: no Java, Node or Postgres needed on the host.
# Usage: make            -> build + test both apps, then start everything

# check for the .env file
ifeq (,$(wildcard .env))
$(error .env not found. Run: cp .env.example .env  (then edit the values))
endif
include .env

SHELL := /bin/bash

.DEFAULT_GOAL := all
.PHONY: all test test-backend test-frontend build build-backend build-frontend up down logs ps backup restore clean

all: build up

# run the tests in Docker, JUnit reports in reports/<app>
test:
	scripts/run-tests.sh

test-backend:
	scripts/run-tests.sh backend

test-frontend:
	scripts/run-tests.sh frontend

build: build-backend build-frontend

build-backend:
	@echo "--Build + test backend, export app.jar to backend/build--"
	docker build --target export --output ./backend/build ./backend
	docker build -t $(BACKEND_IMAGE) ./backend

build-frontend:
	@echo "--Build + test frontend, export dist to frontend/dist--"
	docker build --target export --output ./frontend/dist ./frontend
	docker build -t $(FRONTEND_IMAGE) ./frontend

up:
	docker compose up -d
	@echo "Frontend: http://localhost:$(FRONTEND_PORT)"
	@echo "Backend:  http://localhost:$(BACKEND_PORT)"

down:
	docker compose down

logs:
	docker compose logs -f

ps:
	docker compose ps

# run a database backup now (also runs on BACKUP_CRON_EXPRESSION)
backup:
	docker compose exec backup backup
	@ls -1t backups | head -1

# restore a backup: make restore FILE=backups/backup-xxxx.tar.gz
restore:
	@test -n "$(FILE)" || (echo "Usage: make restore FILE=backups/backup-xxxx.tar.gz" && exit 1)
	@test -f "$(FILE)" || (echo "File not found: $(FILE)" && exit 1)
	set -o pipefail; tar -xOzf $(FILE) /backup/db-dumps/dump.sql | docker compose exec -T db sh -c 'psql -q -U "$$POSTGRES_USER" -d "$$POSTGRES_DB"'

# stop everything and remove build outputs (database volume and backups are kept)
clean: down
	rm -rf backend/build frontend/dist reports
