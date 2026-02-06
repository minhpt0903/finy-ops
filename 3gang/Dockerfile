FROM adoptopenjdk:11-jdk-hotspot
ENV TZ="Asia/Ho_Chi_Minh"
EXPOSE 9019
ARG JAR_FILE=build/libs/api-0.0.1-SNAPSHOT.jar
#ARG JAR_FILE=/api-0.0.1-SNAPSHOT.jar
COPY ${JAR_FILE} api-0.0.1-SNAPSHOT.jar
# ADD ${JAR_FILE} api-0.0.1-SNAPSHOT.jar
VOLUME /logs
ENTRYPOINT ["java", "-jar", "/api-0.0.1-SNAPSHOT.jar"]