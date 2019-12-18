FROM adoptopenjdk/maven-openjdk8-openj9:latest as builder

WORKDIR /build

COPY pom.xml .

RUN mvn dependency:go-offline

COPY src/ /build/src

RUN mvn clean package -DskipTests=true

FROM adoptopenjdk/openjdk8-openj9:alpine

COPY --from=builder /build/target/gs-producing-web-service-0.1.0.jar /app.jar

EXPOSE 8080 8000

ENV JAVA_TOOL_OPTIONS "-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=8000,quiet=y"

# Create a group and user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Perform any further action as an unprivileged user.
USER appuser

CMD ["java", "-Djava.security.egd=file:/dev/./urandom", "-jar", "/app.jar"]
