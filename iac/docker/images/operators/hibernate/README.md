# Cloud hibernate operator (night-park)

**Business first:** non-prod that runs 24/7 is the usual leak. I put scheduled stop and start on Huawei-class (cloud.ru) CCE workers and ECS so nights and weekends do not look like production on the invoice.

Review page: [`../../../../../architecture/02-finops-night-park.md`](../../../../../architecture/02-finops-night-park.md). Ansible slug: [`../../../../ansible/reference/ansible-estate/`](../../../../ansible/reference/ansible-estate/). Terraform sketch: [`../../../../terraform/examples/night-park/`](../../../../terraform/examples/night-park/). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).

```text
hibernate/
  Dockerfile              # python:3.11-alpine, USER clusteradmin, API :8080
  src/
    main.py api_server.py
    cloud_api.py          # IAM token, CCE, ECS
    cluster_manager.py ecs_instance_manager.py schedule_manager.py
    config.py logger.py telegram_notifier.py swagger.json
    requirements.txt
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Calendar in ENV | `CLUSTERS_CONFIG` JSON. `hibernate_schedule` like `from 22:00 monday to 08:00 tuesday`. Time outside that window is awake. |
| Worker discovery | CCE lists nodes (`kind == Node`), then ECS batch stop/start. Standalone VMs use `ECS_INSTANCES_CONFIG`, not a second copy of cluster workers. |
| REST + override | On-demand hibernate/awake. Manual API sets a schedule override (default 24h) so the calendar does not fight the human. |
| API lock | API key header + CIDR allowlist. `/health` stays open. |
| Verify + retry | After stop/start, wait, re-read status, retry, Telegram. The process does not exit on a single API error. |

IAM is password auth against `iam.example.com` (placeholders). Endpoints `cce.example.com` / `ecs.example.com`. Cluster and project ids in examples are fake UUIDs.

```bash
docker build -t example.registry/estate/base-images/cloud-hibernate-operator:3.2.1 .
docker run -d --name cloud-hibernate-operator \
  -e IAM_ENDPOINT=iam.example.com \
  -e IAM_USERNAME=CHANGE_ME \
  -e IAM_PASSWORD=CHANGE_ME \
  -e IAM_DOMAIN_NAME=CHANGE_ME \
  -e IAM_PROJECT_NAME=CHANGE_ME \
  -e CCE_ENDPOINT=cce.example.com \
  -e ECS_ENDPOINT=ecs.example.com \
  -e CLUSTERS_CONFIG='[{"cluster_id":"00000000-0000-4000-8000-0000000000c1","name":"demo-cluster","project_id":"aaaaaaaa000040008000000000000001","hibernate_schedule":"from 22:00 monday to 08:00 tuesday"}]' \
  -e API_KEYS=CHANGE_ME \
  -e API_ALLOWED_IPS=10.10.0.0/16 \
  -e TELEGRAM_BOT_TOKEN=CHANGE_ME \
  -e TELEGRAM_CHAT_IDS=-1000000000001 \
  -p 8080:8080 \
  example.registry/estate/base-images/cloud-hibernate-operator:3.2.1
```

```bash
curl -H "X-API-Key: CHANGE_ME" http://127.0.0.1:8080/api/clusters
curl -X POST -H "X-API-Key: CHANGE_ME" \
  http://127.0.0.1:8080/api/clusters/00000000-0000-4000-8000-0000000000c1/hibernate
```

Prod stays off this calendar. The FinOps page is the buyer review; this folder is the operator image that implements it.
