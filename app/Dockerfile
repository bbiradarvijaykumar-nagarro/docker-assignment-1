# build stage - only this layer needs the JDK + Maven, kept out of the final image
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /build
COPY pom.xml .
# separate layer so dependency downloads get cached and skipped when only src/ changes
RUN mvn -q dependency:go-offline
COPY src ./src
RUN mvn -q -DskipTests package

# runtime stage - just the JRE + the jar, much smaller than the build image
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
# don't run the app as root inside the container
RUN addgroup -S spring && adduser -S spring -G spring
COPY --from=build /build/target/docker-assignment-app.jar app.jar
USER spring
EXPOSE 8080
# lets "docker ps" and docker-compose show real health instead of just "running"
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD wget -qO- http://localhost:8080/actuator/health | grep -q '"status":"UP"' || exit 1
ENTRYPOINT ["java", "-jar", "app.jar"]
