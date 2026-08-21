# Jira Service Management + javaagent

**Business first:** the shop service desk is **JSM with a local agent JAR in Catalina**, not a vanilla Atlassian tag. Hub: [`../../../`](../../../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).

I used this Dockerfile on the JSM 10.3.8 host when a javaagent had to load from `/opt/atlassian/agent.jar` via `setenv.sh`. The `cacerts` copy is the operated TLS shape. The agent JAR and the truststore are not in git.

```text
jsm/
  Dockerfile    # atlassian/jira-servicemanagement:10.3.8, javaagent, COPY cacerts
```

```bash
# from this directory, after maven/agent/target/agent-jar-with-dependencies.jar
# and a local cacerts file are present:
docker build -t example.registry/shop-app/jsm:10.3.8 .
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Pin `10.3.8` | Operated JSM tag |
| `CATALINA_OPTS` javaagent | Agent path is in `setenv.sh`, not a one-off `docker run` flag |
| `COPY cacerts` | Estate TLS into the bundled OpenJDK |

## Honest gap

The agent JAR (`agent-jar-with-dependencies.jar`) and `cacerts` are not in this folder. `docker build` from this directory alone fails on both `COPY` lines. I did not invent a dummy JAR or a placeholder truststore.

This is the **image**. Host Jira / wiki / service-desk compose lives under the collab slice, not here.

**Keywords:** Jira Service Management, javaagent, Catalina, cacerts
