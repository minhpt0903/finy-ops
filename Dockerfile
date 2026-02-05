# Multi-stage build for Spring Boot 2.7.8 application
FROM gradle:8.5-jdk17 AS builder

# Set working directory
WORKDIR /app

# Copy Gradle files and download dependencies (layer caching)
COPY build.gradle settings.gradle gradlew ./
COPY gradle ./gradle
RUN ./gradlew dependencies --no-daemon || true

# Copy source code
COPY src ./src

# Build arguments
ARG SPRING_PROFILE=production
ARG KAFKA_SERVERS=kafka:9092

# Build application
RUN ./gradlew clean build -x test --no-daemon -Pspring.profiles.active=${SPRING_PROFILE}

# Runtime stage
FROM eclipse-temurin:17-jre-alpine

# Install curl for health checks
RUN apk add --no-cache curl

# Create app user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Set working directory
WORKDIR /app

# Copy jar from builder stage
COPY --from=builder /app/build/libs/*.jar app.jar

# Change ownership
RUN chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Environment variables
ENV JAVA_OPTS="-Xms512m -Xmx1024m" \
    SPRING_PROFILES_ACTIVE=production \
    SPRING_KAFKA_BOOTSTRAP_SERVERS=kafka:9092

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8080/actuator/health || exit 1

# Run application
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
