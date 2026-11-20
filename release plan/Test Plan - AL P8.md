# Test Plan

## Table of contents

- [1. Introduction](#1-introduction)
- [2. Unit tests](#2-unit-tests)
  - [2.1 Scope and objectives](#21-scope-and-objectives)
  - [2.2 Tools and technologies](#22-tools-and-technologies)
  - [2.3 Success criteria](#23-success-criteria)
  - [2.4 Run commands and reports](#24-run-commands-and-reports)
  - [2.5 Run frequency](#25-run-frequency)
- [3. Integration tests](#3-integration-tests)
  - [3.1 Scope and objectives](#31-scope-and-objectives)
  - [3.2 Recommended tools and technologies](#32-recommended-tools-and-technologies)
  - [3.3 Priority test scenarios](#33-priority-test-scenarios)
  - [3.4 Success criteria](#34-success-criteria)
  - [3.5 Recommended run frequency](#35-recommended-run-frequency)
- [4. Performance tests](#4-performance-tests)
  - [4.1 Scope and objectives](#41-scope-and-objectives)
  - [4.2 Recommended tools and technologies](#42-recommended-tools-and-technologies)
  - [4.3 Recommended metrics and thresholds](#43-recommended-metrics-and-thresholds)
  - [4.4 Load scenarios](#44-load-scenarios)
  - [4.5 Recommended run frequency](#45-recommended-run-frequency)
- [5. Security tests](#5-security-tests)
  - [5.1 Scope and objectives](#51-scope-and-objectives)
  - [5.2 Recommended tools and technologies](#52-recommended-tools-and-technologies)
  - [5.3 Priority vulnerabilities to check](#53-priority-vulnerabilities-to-check)
  - [5.4 Recommended success criteria](#54-recommended-success-criteria)
  - [5.5 Recommended run frequency](#55-recommended-run-frequency)
- [6. Features to test](#6-features-to-test)
- [7. Features not to test](#7-features-not-to-test)
- [8. Test summary matrix](#8-test-summary-matrix)
- [Notes and references](#notes-and-references)

## 1. Introduction

This plan covers two applications shipped as Docker images and deployed with Docker Compose:

- **Olympic Participation Tracker** (front-end): Angular 20.3.7 / TypeScript 5.8.3, built with Node 22 and served by `nginx:1.27-alpine`. Data comes from a static JSON file (`src/assets/mock/olympic.json`). The front-end does not call the API.
- **Workshop Organizer API** (back-end): Java 21, Spring Boot 3.2.4, Gradle 8.7, PostgreSQL 13. REST API generated from an OpenAPI 3.0.3 spec (`/api/notions`, `/api/workshops`).

The CI/CD pipeline (GitHub Actions) runs the tests in Docker, publishes the JUnit reports, and pushes the image to GHCR only if the tests pass.

**Current state:** only unit tests exist. The integration, performance and security tests described here are **recommended** before going to production.

## 2. Unit tests

Unit tests run in the `test` stage of the Dockerfiles. If a test fails, the image is not built.

### 2.1 Scope and objectives

**Back-end:** 3 test classes, 2 actual tests.

- `NotionServiceTest.createNotion()`: creates a notion, repository mocked with Mockito.
- `WorkshopServiceTest.createWorkshop()`: creates a workshop, repository mocked.
- `JavaBasicAppApplicationTests`: `@SpringBootTest` with no test method, so it checks nothing.
- **Not covered:** controllers (`NotionController`, `WorkshopController`), `getAll()`, `getById()`, ModelMapper mapping, repositories, `WebMvcConfig` (`/api` prefix).

**Front-end:** 4 spec files, 5 tests, all smoke tests ("should create").

- `app.component.spec.ts` (2 tests: create, title), `olympic.service.spec.ts` (1), `home.component.spec.ts` (1), `not-found.component.spec.ts` (1).
- **Not covered:** what `getOlympics()` returns, error handling (`catchError`), the route resolver, how participations are displayed, the 404 route.

**Coverage:** no figures available. JaCoCo is not configured and Karma is not run with `--code-coverage`.

### 2.2 Tools and technologies

| Application | Tool | Version |
|---|---|---|
| Back-end | JDK / build | Java 21 (`gradle:8.7-jdk21`), Gradle 8.7 |
| Back-end | Framework | Spring Boot 3.2.4 |
| Back-end | Tests | JUnit Jupiter 5.10.x + Mockito 5.7.x (via `spring-boot-starter-test`, Spring Boot 3.2.4 BOM) |
| Back-end | Reports | Gradle JUnit XML (`build/test-results/test`) |
| Front-end | Runtime | Node 22 (`node:22-bookworm-slim`), Angular CLI 20.3.7, TypeScript 5.8.3 |
| Front-end | Runner / framework | Karma 6.4.4, Jasmine 4.2.0 (karma-jasmine 5.1.0) |
| Front-end | Browser | Headless Chromium (Debian), via karma-chrome-launcher 3.1.1 |
| Front-end | Reports | karma-junit-reporter 2.0.1, karma-coverage 2.2.1 (installed, not enabled) |
| Both | Execution | Docker BuildKit (`docker build --target test-reports`), `scripts/run-tests.sh` |
| Both | CI | GitHub Actions, `mikepenz/action-junit-report@v5`, `actions/upload-artifact@v4` |

### 2.3 Success criteria

**Today:** 100% of tests must pass (exit code 0), otherwise the build fails. No coverage threshold is enforced.

**Recommended thresholds:**

| Criterion | Back-end | Front-end |
|---|---|---|
| Tests passed | 100% | 100% |
| Line coverage (overall) | ≥ 70% (JaCoCo) | ≥ 70% (karma-coverage) |
| Service layer coverage | ≥ 80% | ≥ 80% (Angular services) |
| Branch coverage | ≥ 60% | ≥ 60% |

Why: 70–80% is the usual level (for example, SonarQube's default quality gate requires 80% on new code). Going higher costs a lot for little gain. Code generated by OpenAPI (`src/main/java-generated`) is excluded from the calculation.

**To set up:** the `jacoco` plugin with `jacocoTestCoverageVerification` in `build.gradle`, and `ng test --code-coverage` with `check` in `karma.conf.js`.

### 2.4 Run commands and reports

All commands run from the repository root. Only Docker is needed; nothing else has to be installed on the host.

```bash
make test              # back-end + front-end
make test-backend      # = scripts/run-tests.sh backend
make test-frontend     # = scripts/run-tests.sh frontend
```

Without Docker (tools installed locally):

```bash
cd backend && ./gradlew test
cd frontend && npm ci && npm test                    # ng test --watch false
cd frontend && npm test -- --code-coverage           # with coverage
```

| Application | Report | Location |
|---|---|---|
| Back-end | JUnit XML | `reports/backend/TEST-*.xml` (local: `backend/build/test-results/test/`) |
| Front-end | JUnit XML | `reports/frontend/TESTS-Chrome_Headless_*.xml` |
| Both | Exit code | `reports/<app>/test-exit-code` |
| Front-end | Coverage (if enabled) | `frontend/coverage/olympic-games-starter/` |
| CI | Artifact + check | `<app>-test-reports` artifact + JUnit summary on the PR |

Last run (2026-11-13): back-end 2/2 and front-end 5/5 passed, 0 failures.

### 2.5 Run frequency

- **Developer machine:** before each commit (`make test-<app>`).
- **CI:** on every pull request, every push to `main` and every `v*` tag (`backend.yml` / `frontend.yml` workflows, filtered on changed paths).
- **Build:** every `make build` runs the tests again, and a failure stops the image from being created.
- **Owner:** the Dev team. The PR author fixes failures; the reviewer does not merge while the JUnit check is red.

## 3. Integration tests

Status: **recommended** (not implemented).

### 3.1 Scope and objectives

- **Back-end:** the full chain HTTP → controller → service → JPA → real PostgreSQL: `/api` prefix, JSON serialization, HTTP status codes, workshop ↔ notions ManyToMany relation, schema creation by Hibernate.
- **Front-end:** route `''` → resolver → `OlympicService` → `HomeComponent` (data rendering), route `**` → `NotFoundComponent`, behaviour on HTTP errors.
- **Stack:** `docker compose` startup (db healthy → app), API and front-end respond.

### 3.2 Recommended tools and technologies

| Application | Tool | Why |
|---|---|---|
| Back-end | `@SpringBootTest` + MockMvc (or `TestRestTemplate`) | Already in `spring-boot-starter-test`, tests the whole Spring chain |
| Back-end | Testcontainers `postgres:13` | Same version as production, unlike H2 |
| Front-end | `HttpClientTestingModule` / `HttpTestingController` | Built into Angular, fakes the JSON and errors |
| Front-end | `RouterTestingHarness` (Angular) | Tests route + resolver + component |
| Stack | `docker compose` + curl script in CI | Checks the images that are actually shipped |

Environment: `ubuntu-latest` CI runner with Docker (already required by the pipeline), throwaway database created by Testcontainers, Spring `test` profile.

### 3.3 Priority test scenarios

| ID | Scenario | Data | Expected result |
|---|---|---|---|
| INT-B1 | `POST /api/notions` then `GET /api/notions` | notion `{name:"Docker"}` | 200, the notion is in the list |
| INT-B2 | `POST /api/workshops` with 2 existing notions | notions Docker, K8s; workshop "Workshop 1" | 200, generated id, notions linked in the database |
| INT-B3 | `GET /api/workshops/{id}` for an existing id | workshop created in B2 | 200, name + notions |
| INT-B4 | `GET /api/workshops/9999` unknown id | empty database | 404 expected (today: 200 with empty body → defect) |
| INT-B5 | Data survives an app restart | workshop created, container restarted | data still there |
| INT-F1 | Home page loads | `olympic.json` (5 countries) | "5 data loaded" + "JO de {city} - {year}" lines |
| INT-F2 | HTTP error on the JSON | simulated 500 response | error message, no loop (today `catchError` retries the request forever) |
| INT-F3 | Unknown URL `/xyz` | - | NotFound page |

### 3.4 Success criteria

- 100% of scenarios pass. A single failure blocks the merge, because these tests check the contracts between layers.
- Runs in under 5 min in CI, so PRs stay fast.
- No flaky tests tolerated: an unstable test is fixed or quarantined within 48 h.

### 3.5 Recommended run frequency

- On every pull request and every push to `main`, in an `integration` job that runs after the `test` job.
- **Owner:** Devs write and maintain the tests; QA validates the scenarios and follows the results.

## 4. Performance tests

Status: **recommended** (not implemented).

### 4.1 Scope and objectives

- **API:** `GET /api/workshops` (most called, EAGER relation), `GET /api/workshops/{id}`, `POST /api/workshops`, `GET /api/notions`.
- **Front-end:** load time of the home page (bundle + JSON) served by nginx.
- **Resources:** container CPU and RAM against the Compose limits (app 1 CPU / 768M, db 1 CPU / 512M, front 0.5 CPU / 128M).

### 4.2 Recommended tools and technologies

| Tool | Target | Why |
|---|---|---|
| k6 (Grafana k6) | API | JS scripts kept in Git, built-in `thresholds`, Docker image, fits into CI |
| Lighthouse CI | Front-end | Measures LCP, TBT, CLS and asset weight, with one assertion per threshold |
| `docker stats` / cAdvisor | Containers | CPU and RAM usage during the test |

Setup: stack started with `make up` on a dedicated machine (not a dev laptop), database pre-filled with about 1,000 workshops, k6 run from a separate container.

### 4.3 Recommended metrics and thresholds

| Metric | Threshold | Rationale |
|---|---|---|
| API response time p95 | < 300 ms | Simple CRUD API, should feel instant |
| API response time p99 | < 1 s | Safety net against spikes |
| HTTP error rate | < 1% | Standard availability target |
| Sustained throughput | ≥ 50 req/s | Well above expected usage (internal tool) |
| Front-end LCP | < 2.5 s | Core Web Vitals "Good" threshold |
| Initial bundle | < 500 kB (error at 1 MB) | Budgets set in `angular.json` |
| App container RAM | < 80% of 768M | Avoids OOM kills |

### 4.4 Load scenarios

| Scenario | Parameters | Goal |
|---|---|---|
| Nominal load | 20 VUs, 10 min, 80% GET / 20% POST | Check thresholds under normal use |
| Peak (stress) | ramp 0 → 200 VUs over 5 min | Find the breaking point |
| Soak | 20 VUs for 30 min | Detect memory leaks and JDBC pool exhaustion |
| Front-end | Lighthouse, 3 runs, mobile profile | Check LCP and budgets |

### 4.5 Recommended run frequency

- Before each release (`v*` tag) and after any change to the database or resource limits.
- Weekly scheduled nominal load test (`schedule`) once the application is in production.
- **Owner:** Ops run and analyse; Devs fix. The go/no-go decision belongs to the tech lead.

## 5. Security tests

Status: **recommended** (not implemented).

### 5.1 Scope and objectives

- Dependencies: Gradle (Spring Boot 3.2.4, PostgreSQL driver 42.7.3, ModelMapper 3.1.0) and npm (Angular 20.3.7).
- Docker images: `eclipse-temurin:21-jre-alpine`, `nginx:1.27-alpine`, `postgres:13`, `offen/docker-volume-backup:v2`.
- Running API: input validation, missing authentication, HTTP headers.
- Secrets: `.env` (PostgreSQL password), Git repository, workflows.

### 5.2 Recommended tools and technologies

| Tool | Use | Integration |
|---|---|---|
| Trivy | CVEs in images + dependencies, Dockerfile misconfiguration | CI step after build, before the GHCR push |
| OWASP Dependency-Check (or Dependabot) | CVEs in Gradle dependencies | Gradle plugin / GitHub alerts |
| `npm audit` | CVEs in npm dependencies | Front-end CI step |
| OWASP ZAP baseline | DAST scan of the API and front-end | CI job against the `docker compose` stack |
| Gitleaks | Committed secrets | Pre-commit + CI |

Why: free, open-source tools that plug easily into GitHub Actions and cover the code, the images and the running application.

### 5.3 Priority vulnerabilities to check

- **A01 Broken Access Control:** the API has no authentication; anyone can create workshops.
- **A03 Injection:** `name` inputs on notions and workshops (JPA protects against SQL injection, but nothing validates the data).
- **A05 Security Misconfiguration:** `spring.jpa.show-sql=true`, Swagger UI exposed in production, missing nginx headers (CSP, X-Frame-Options).
- **A06 Vulnerable components:** `postgres:13` is out of support (November 2025); images must be rebuilt regularly.
- **Secrets:** `.env` is ignored by Git (OK). The default value `change_me` must be forbidden.
- **Containers:** app and front-end already run as a non-root user (OK). The Docker socket is mounted read-only in `backup` (to keep an eye on).

### 5.4 Recommended success criteria

| Severity | Accepted threshold | Fix deadline |
|---|---|---|
| Critical (CVSS ≥ 9) | 0, blocks the image push | 24 h |
| High (7–8.9) | 0 at release | 7 days |
| Medium (4–6.9) | tolerated with a ticket | 30 days |
| Low | tolerated | next maintenance |
| Secret detected | 0 | immediately (rotate the secret) |

### 5.5 Recommended run frequency

- Trivy, `npm audit` and Gitleaks: on every PR and every build.
- ZAP scan: weekly, and before each release.
- Dependency review: monthly (Dependabot).
- **Owner:** DevSecOps follows the results, Devs fix, Ops rebuild and redeploy the images.

## 6. Features to test

| Feature | Application | Why it matters | Test types |
|---|---|---|---|
| Create / list notions | Back | Core data for workshops | Unit, integration |
| Create a workshop with its notions | Back | ManyToMany relation, MERGE cascade | Unit, integration |
| Get a workshop by id | Back | Wrong status code today (200 instead of 404) | Integration |
| PostgreSQL persistence | Back / Ops | Data must survive restarts | Integration |
| Home page (JSON load + display) | Front | Only business screen | Unit, integration, perf |
| Service error handling | Front | Possible infinite loop | Unit |
| 404 page | Front | Navigation | Unit |
| Backup / restore | Ops | Data protection | Monthly restore test |
| CI pipeline: blocking tests | CI/CD | Stops a broken image from shipping | Checked on every PR |

## 7. Features not to test

| Exclusion | Reason |
|---|---|
| Code generated by OpenAPI (`src/main/java-generated`) | Generated from `openapi.yaml`, not maintained by hand |
| Swagger UI (`/`) | Third-party static resource, no business logic |
| `k8s/` manifests and `values.tpl.yaml` | Unfinished (image fields are TODO), not used for deployment |
| Legacy `backend/db/` script (SQL seed) | Not used by Compose; the schema is created by Hibernate |
| `limit` parameter of `GET /api/workshops` | Not implemented in the service; test it once it is built |
| Third-party libraries (Angular, Spring, nginx) | Tested by their maintainers, covered by vulnerability scanning |
| Cross-browser compatibility | Internal tool; headless Chromium is enough for now |

## 8. Test summary matrix

Implemented = in place in the repository and CI. Recommended = to set up before going to production.

| Test type | Tool(s) | Frequency | Owner (Dev / QA / Ops / DevSecOps) | Success criteria | Status (Implemented / Recommended) |
|---|---|---|---|---|---|
| Back-end unit | JUnit 5, Mockito, Gradle 8.7 | Every commit / PR / push | Dev | 100% pass; coverage target ≥ 70% | Implemented (coverage: Recommended) |
| Front-end unit | Karma 6.4, Jasmine 4.2, Chromium | Every commit / PR / push | Dev | 100% pass; coverage target ≥ 70% | Implemented (coverage: Recommended) |
| Back-end integration | SpringBootTest, MockMvc, Testcontainers | Every PR | Dev / QA | 100% pass, < 5 min | Recommended |
| Front-end integration | HttpTestingController, RouterTestingHarness | Every PR | Dev / QA | 100% pass | Recommended |
| Compose stack smoke test | docker compose, curl | Every push to main | Ops | API 200, front 200 | Recommended |
| API performance | k6 | Before release + weekly | Ops | p95 < 300 ms, errors < 1% | Recommended |
| Front-end performance | Lighthouse CI | Before release | Ops / Dev | LCP < 2.5 s, bundle < 500 kB | Recommended |
| Dependency / image security | Trivy, npm audit, Dependabot | Every PR | DevSecOps | 0 critical / 0 high | Recommended |
| DAST security | OWASP ZAP | Weekly + release | DevSecOps | 0 high alerts | Recommended |
| Secrets | Gitleaks | Pre-commit + PR | DevSecOps | 0 secrets | Recommended |
| Backup restore | make backup / make restore | Monthly | Ops | Identical data, API OK | Recommended |

## Notes and references

- JUnit 5: https://junit.org/junit5/docs/current/user-guide/
- Spring Boot Testing: https://docs.spring.io/spring-boot/reference/testing/
- Testcontainers: https://java.testcontainers.org/modules/databases/postgres/
- JaCoCo Gradle: https://docs.gradle.org/current/userguide/jacoco_plugin.html
- Angular Testing: https://angular.dev/guide/testing
- Karma: https://karma-runner.github.io/
- k6: https://grafana.com/docs/k6/latest/
- Lighthouse CI: https://github.com/GoogleChrome/lighthouse-ci
- OWASP Top 10: https://owasp.org/Top10/
- Trivy: https://trivy.dev/  |  OWASP ZAP: https://www.zaproxy.org/

**Choices:** everything runs in Docker so results are the same on a laptop and in CI. Tests are blocking in the Dockerfile, so a published image has always passed its tests. The recommended tools are free and easy to plug into GitHub Actions.

**Defects found during the analysis:** `getById` returns 200 instead of 404; POSTs return 200 instead of 201; the front-end `catchError` retries the request forever; `limit` is ignored; the `JavaBasicAppApplicationTests` test is empty.
