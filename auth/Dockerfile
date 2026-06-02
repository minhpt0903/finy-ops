# ─── Stage 1: Build ───────────────────────────────────────────────────────────
FROM docker.io/eclipse-temurin:17-jdk-alpine AS builder

WORKDIR /app

# Pass private GitLab token at build time
ARG GITLAB_TOKEN

# Copy Gradle wrapper & config first (layer cache)
COPY gradlew gradlew.bat settings.gradle build.gradle ./
COPY gradle ./gradle
RUN chmod +x gradlew

# Pre-download dependencies (cache layer, invalidated only when build.gradle changes)
RUN ./gradlew dependencies --no-daemon \
    -PmyGitlabToken=${GITLAB_TOKEN} \
    --configuration runtimeClasspath \
    2>/dev/null || true

# Copy source and build
COPY src ./src
RUN ./gradlew bootJar --no-daemon \
    -PmyGitlabToken=${GITLAB_TOKEN} \
    -x test

# Extract jar into layers (dependencies change rarely, app layer changes every commit)
RUN java -Djarmode=layertools -jar build/libs/*.jar extract --destination extracted

# ─── Stage 2: Runtime ─────────────────────────────────────────────────────────
FROM docker.io/eclipse-temurin:17-jre-alpine

WORKDIR /app

RUN apk add --no-cache tzdata && \
    addgroup -S -g 1001 appgroup && adduser -S -u 1001 -G appgroup appuser && \
    mkdir -p /logs && chown appuser:appgroup /logs

COPY --from=builder /app/extracted/dependencies/ ./
COPY --from=builder /app/extracted/spring-boot-loader/ ./
COPY --from=builder /app/extracted/snapshot-dependencies/ ./
COPY --from=builder /app/extracted/application/ ./

RUN chown -R appuser:appgroup /app
USER appuser

ENV TZ="Asia/Ho_Chi_Minh"

EXPOSE 8000

ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]
