FROM maven:3-eclipse-temurin-8 as builder

WORKDIR /home/src

COPY . /home/src

RUN mvn clean package

FROM tomcat:8.0.36-jre8

RUN rm -rf /usr/local/tomcat/webapps/*

COPY --from=builder /home/src/target/log4shell-1.0-SNAPSHOT.war /usr/local/tomcat/webapps/ROOT.war
COPY --from=docker.io/debian /usr/bin/unshare /usr/bin/unshare

EXPOSE 8080
CMD ["catalina.sh", "run"]
