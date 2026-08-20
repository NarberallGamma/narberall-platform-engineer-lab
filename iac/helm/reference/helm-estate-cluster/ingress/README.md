# ingress-nginx values

I did not invent a wrapper chart. CI installed upstream **ingress-nginx 1.13.3** with this values excerpt.

`values.example.yaml` is the contract: 3 replicas, zone anti-affinity, PDB `minAvailable: 2`, `controller.service.enabled: false`. Config covers gzip, workers, timeouts, `proxy-body-size 10m`, TLS 1.2/1.3, rate-limit **1000 / 1m**, `server-tokens: false`. Metrics and ServiceMonitor stay on (`namespace: monitoring`).

The three cloud ELB Services live in `../loadbalancer/`.

```text
ingress/
  values.example.yaml
  README.md
```

**Keywords:** ingress-nginx, rate-limit, TLS, ServiceMonitor, PDB
