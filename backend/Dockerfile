# Stage 1: test (JDK 21 + Gradle)
FROM gradle:8.7-jdk21 AS test

WORKDIR /app

COPY build.gradle settings.gradle ./
COPY src ./src

# openApiGenerate + compile + test
# never fails here: the exit code is saved so the reports can be exported even when a test fails
# --no-daemon make gradle run in a fresh jvm
RUN gradle test --no-daemon; echo $? > /app/test-exit-code

###
# Stage 2: export only the JUnit reports + exit code to the host
# docker build --target test-reports --output ./reports/backend ./backend
FROM scratch AS test-reports

COPY --from=test /app/build/test-results/test /
COPY --from=test /app/test-exit-code /

###
# Stage 3: build (fails if a test failed, reuses the compiled classes)
FROM test AS build

RUN [ "$(cat /app/test-exit-code)" = "0" ] && gradle bootWar --no-daemon

###
# Stage 4: export only app.jar to the host
# docker build --target export --output ./backend/build ./backend
FROM scratch AS export

COPY --from=build /app/build/libs/*.war /app.jar

###
# Stage 5: runtime (default target)
FROM eclipse-temurin:21-jre-alpine

# run the app as a non-root user
RUN addgroup -S app && adduser -S app -G app

COPY --from=build --chown=app:app /app/build/libs/*.war /app.jar

USER app

ENTRYPOINT ["java","-jar","/app.jar"]
