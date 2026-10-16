# ==========================================
# Stage 1: Build application using Gradle
# ==========================================
FROM gradle:8.5-jdk21-alpine AS builder

WORKDIR /app

# Copy Gradle wrapper and configuration files first to leverage layer caching
COPY gradlew .
COPY gradle gradle
COPY build.gradle settings.gradle ./

# Grant execution rights and pre-fetch dependencies
RUN chmod +x gradlew && ./gradlew dependencies --no-daemon

# Copy source code and build executable jar
COPY src src
RUN ./gradlew bootJar -x test --no-daemon

# ==========================================
# Stage 2: Runtime image (Alpine JRE)
# ==========================================
FROM eclipse-temurin:21-jre-alpine

WORKDIR /app

# Security: Create non-root user and group
RUN addgroup -S daonbmgroup && adduser -S daonbm -G daonbmgroup

# Copy built JAR from builder stage and assign ownership
COPY --from=builder --chown=daonbm:daonbmgroup /app/build/libs/*.jar app.jar

# Switch to non-root user
USER daonbm

# Expose application port
EXPOSE 8083

# Recommended JVM flags for containerized environment
ENTRYPOINT ["java", "-Djava.security.egd=file:/dev/./urandom", "-jar", "app.jar"]
