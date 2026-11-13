# Stage 1: test (Node 22 + headless Chromium for Karma)
FROM node:22-bookworm-slim AS test

# ChromeHeadless is used by karma.conf.js
RUN apt-get update \
    && apt-get install -y --no-install-recommends chromium \
    && rm -rf /var/lib/apt/lists/*
ENV CHROME_BIN=/usr/bin/chromium

WORKDIR /app

# install dependencies first so this layer is cached until package*.json change
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm \
    npm ci

COPY . .

# never fails here: the exit code is saved so the reports can be exported even when a test fails
RUN npm test; echo $? > /app/test-exit-code

###
# Stage 2: export only the JUnit reports + exit code to the host
# docker build --target test-reports --output ./reports/frontend ./frontend
FROM scratch AS test-reports

COPY --from=test /app/reports /
COPY --from=test /app/test-exit-code /

###
# Stage 3: build the production bundle (fails if a test failed)
FROM test AS build

RUN [ "$(cat /app/test-exit-code)" = "0" ] && npm run build

###
# Stage 4: export only the built app to the host
# docker build --target export --output ./frontend/dist ./frontend
FROM scratch AS export

COPY --from=build /app/dist/olympic-games-starter/browser /

###
# Stage 5: runtime (default target)
FROM nginx:1.27-alpine

# project nginx config: serves /app on port 80, pid and temp files in /tmp
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY --from=build --chown=nginx:nginx /app/dist/olympic-games-starter/browser /app

# run nginx as a non-root user
RUN chown -R nginx:nginx /var/cache/nginx /var/log/nginx
USER nginx
