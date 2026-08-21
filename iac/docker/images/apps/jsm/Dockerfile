FROM atlassian/jira-servicemanagement:10.3.8
COPY ./maven/agent/target/agent-jar-with-dependencies.jar /opt/atlassian/
RUN mv /opt/atlassian/agent-jar-with-dependencies.jar /opt/atlassian/agent.jar
RUN echo 'export CATALINA_OPTS="-javaagent:/opt/atlassian/agent.jar ${CATALINA_OPTS}"' >> /opt/atlassian/jira/bin/setenv.sh
COPY ./cacerts /opt/java/openjdk/lib/security/
