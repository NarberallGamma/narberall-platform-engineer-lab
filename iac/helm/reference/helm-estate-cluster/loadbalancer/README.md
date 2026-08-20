# 3-ELB loadbalancer chart

I owned cloud load balancers as **three Services**, not as the ingress-nginx Service. Each Service maps one zone (`zone-a`, `zone-b`, `zone-c`). Selector is `ingress-nginx` / `controller`. `externalTrafficPolicy` is `Local` so the balancer sees the real client hop and skips extra node hops.

```text
loadbalancer/
  Chart.yaml
  values.yaml
  templates/service.yaml
  templates/NOTES.txt
  README.md
```

Vendor project names and autocreate JSON are stripped. Comments in the template record the L4 / bandwidth / TCP health-check pattern.

Pair this with `../ingress/values.example.yaml` (`controller.service.enabled: false`).

**Keywords:** LoadBalancer, ingress-nginx, zone, externalTrafficPolicy Local
