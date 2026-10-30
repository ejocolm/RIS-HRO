# --- build ---
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /src
COPY pom.xml .
RUN mvn -q -B dependency:go-offline
COPY src ./src
# Corre las pruebas de extremo a extremo durante el build
RUN mvn -q -B package

# --- runtime ---
FROM eclipse-temurin:21-jre-alpine
RUN addgroup -S app && adduser -S app -G app
WORKDIR /app
COPY --from=build /src/target/hl7-pdq-mediator.jar /app/app.jar
USER app
EXPOSE 2575
ENV MLLP_PORT=2575 \
    HL7_CHARSET=UTF-8 \
    JAVA_OPTS="-Xms64m -Xmx256m -Dfile.encoding=UTF-8 -Dstdout.encoding=UTF-8"
ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar /app/app.jar"]
