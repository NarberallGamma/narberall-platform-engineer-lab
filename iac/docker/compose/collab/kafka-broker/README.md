# Kafka KRaft broker (host Compose)

**Business first:** a public-facing broker is **KRaft + PEM + a Vault pull**, not the laptop `dev-deps/kafka`. Hub: [`../../../`](../../../). Collab index: [`../`](../). Laptop sibling: [`../../dev-deps/kafka/`](../../dev-deps/kafka/). Ansible role: [`../../../../ansible/reference/ansible-llm-collab/`](../../../../ansible/reference/ansible-llm-collab/). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).

I used `apache/kafka:4.0.0` on `network_mode: host` with four listeners (INTERNAL / CLIENT / EXTERNAL / EIP). A Vault sidecar writes PEM into `./certs`. A `docker:29.1.3` cron sidecar restarts the broker when `eip.pem` is newer than the container start.

```text
kafka-broker/
  docker-compose.yml         # kafka + vault-cert-upload + docker cron
  config/server.properties   # KRaft, 4 listeners, PEM, SCRAM, 3-voter quorum
  config/client.properties   # SSL/PEM client
  crontab                    # weekly cert-mtime check
  check-and-restart.sh       # compose restart when eip.pem is newer
```

```bash
# from this directory, after certs/, data/, and certs/download.sh exist:
docker compose up -d
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Four listeners | Internal quorum vs client vs external vs EIP hostname |
| Vault sidecar | `VAULT_TOKEN=CHANGE_ME`, `SECRET_NAME=kafka-prod-tls` |
| docker.sock cron | Cert rotate without a human restart |
| Ulimits | `nofile` / `nproc` 512000 |

## Honest gap

PEM, `certs/download.sh`, and `./data` stay out of git. Quorum IPs are `10.10.9.11/12/13`; Vault is `10.10.4.92`. `min.insync.replicas=2` with `default.replication.factor=1` is the captured shape. Ansible `kafka_deploy` `.j2` is a different mechanic (SASL PLAIN / AKHQ).

**Keywords:** Kafka, KRaft, PEM, SCRAM, Vault, docker.sock
