# Redis operator (werf teaching tree)

**Business first:** apps that cannot speak Sentinel still get a failover Redis, if a proxy sits in front. Hub: [`../`](../).

I used this tree to install [Spotahome redis-operator](https://github.com/spotahome/redis-operator) once per cluster, then ship `RedisFailover` plus a Sentinel proxy into app namespaces. There is no `Chart.yaml`. Templates live under `.helm/`.

```text
redis-operator/
  werf.yaml
  .gitlab-ci.yml
  .helm/
    values.yaml
    templates/
      operator/redis-operator.yaml
      redis-failover.yaml
      redis-sentinel-proxy-deployment.yaml
      redis-sentinel-proxy-service.yaml
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Operator vs failover split | `global.env=operator` installs the controller. Other envs install `RedisFailover` |
| Sentinel proxy | TCP 6379 for clients that only know a single Redis endpoint |
| Deckhouse Service labels | `prometheus.deckhouse.io/target` on the exporter Services |

```bash
# operator once
werf converge --set global.env=operator --namespace redis-operator

# failover in an app namespace
werf converge --set global.env=estate --namespace redis
```

Operator image is upstream `quay.io/spotahome/redis-operator:v1.0.0`. Sentinel proxy image is `example.registry/redis-sentinel-proxy:1.0.0` (placeholder). Storage class default is `rbd`.

`werf.yaml` stays (`project: redis`). CI stages: operator, then two project environments.

Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).

**Keywords:** Redis, redis-operator, Sentinel, werf, Deckhouse
