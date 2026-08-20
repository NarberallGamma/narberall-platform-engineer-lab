# Istio mesh policy (custom chart)

**Business first:** STRICT mTLS on selected app workloads, plus selective egress (sidecar to egress gateway to VPS proxy). Kit: [`../README.md`](../README.md). Case: [`../../../../../case-studies/11-helm-estate.md`](../../../../../case-studies/11-helm-estate.md).

I wrote this chart so PeerAuthentication and VPS routing CRs ship together. Upstream `base` and `istiod` stay in [`../../helm-mesh-eso/`](../../helm-mesh-eso/). I did not vendor `istio/gateway`; only the HA values excerpt is here.

Brand, live FQDNs, VPS IPs, and product app names are placeholders. Templates stay so a reviewer can parse the CRs.

```text
istio/
  Chart.yaml
  values.yaml
  values-egress-gateway.example.yaml
  templates/
    _helpers.tpl
    peer-authentication.yaml
    vps-egress-serviceentry.yaml
    vps-egress-external-serviceentries.yaml
    vps-egress-destinationrule.yaml
    vps-egress-gateway.yaml
    vps-egress-virtualservice.yaml
  README.md
```

## Who this page is for

Hiring lead: this is the mesh policy I actually ran, not an Istio install wiki. Engineer: copy the chart; use NOTES for the traffic path and the emergency off switch.

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| PeerAuthentication | STRICT mTLS on six generic app Services (`web`, `contract`, `report`, `tx-eth`, `tx-trx`, `tx-svc`) |
| Selective VPS egress | Mesh to egress gateway to STATIC VPS endpoints. Gateway hosts and DNS ServiceEntries are built from **enabled** routes only |
| Route flags | Grafana alert API on. Chain RPC routes off in the prod-shaped values |
| Egress gateway excerpt | 2 replicas, HPA off, zone anti-affinity. Pin I used: `istio/gateway` 1.27.3 |

## Copy vs NOTES

**Copy:** `Chart.yaml`, `templates/`, `values.yaml`, `values-egress-gateway.example.yaml`.

**NOTES:** traffic path, failover, emergency disable (below). Hosts and IPs in values are documentation ranges, not live.

Product node charts are not in this tree. Blockchain in the portfolio is this egress plus ExternalSecret keys elsewhere.

## Values (sanitized)

```yaml
vpsEgress:
  enabled: true
  appNamespace: app
  serviceEntry:
    host: proxy.internal.example
    address: 10.10.255.1          # dummy VIP for STATIC resolution
  endpoints:
    primary:
      address: 203.0.113.10
    backup:
      address: 203.0.113.11
  routes:
    - virtualServiceName: vps-egress-tx-eth
      enabled: false
      sourceAppInstance: tx-eth
      externalHosts:
        - eth.egress.example.com
    - virtualServiceName: vps-egress-tx-trx
      enabled: false
      sourceAppInstance: tx-trx
      externalHosts:
        - trx.egress.example.com
        - trx-grpc.egress.example.com
    - virtualServiceName: vps-egress-grafana
      enabled: true
      namespace: monitoring
      sourceAppInstance: grafana
      externalHosts:
        - alerts.egress.example.com
```

Gateway hosts and DNS ServiceEntries are **not** duplicated as a second list. The chart collects them from `externalHosts` on routes with `enabled: true`.

Namespace injection: label the app namespace (`istio-injection=enabled`). I did not enable injection on the whole `monitoring` namespace. Grafana got a sidecar via pod annotations plus `podLabels.istio.io/rev: default` (needed on Istio 1.27 so the injector webhook matches).

## NOTES

### Traffic path

```text
workload sidecar (inject + istio.io/rev=default)
        |
        v
  VirtualService: mesh + sourceLabels app.kubernetes.io/instance
        |  SNI = host from an enabled route
        v
  istio-egressgateway (istio-system)
        |
        v
  proxy.internal.example  (ServiceEntry STATIC, DestinationRule failover)
        |
        v
  VPS Envoy :443 (203.0.113.10 primary, 203.0.113.11 backup)
        |  TLS passthrough
        v
  external host from enabled routes
```

External providers see a VPS egress IP (`203.0.113.x`), not the pod CIDR and not cluster NAT. Hosts outside enabled `routes[].externalHosts` stay on cluster NAT (`outboundTrafficPolicy: ALLOW_ANY`). That includes SMTP and scrape egress from Grafana.

Routing applies only to pods whose `app.kubernetes.io/instance` equals the Helm release name. Disable one route with `routes[].enabled: false` without setting `vpsEgress.enabled=false`.

### Failover

`DestinationRule` uses `failoverPriority` (primary, then backup) and `outlierDetection`. After a VPS Envoy stop, check egress-gateway Envoy cluster stats for `cx_active` on `203.0.113.10` vs `203.0.113.11`. Workloads should stay Ready while the backup takes the connections.

Sidecar stats that matter: `istio-egressgateway...443` `cx_total` growing. A zero count on the external-host cluster is expected when the path is via the gateway.

### Emergency disable (return to cluster NAT)

When both VPS endpoints are down, remove routing CRs. Leave the egress gateway Deployment in place.

1. Helm override: `helm upgrade` this chart with `--set vpsEgress.enabled=false`. PeerAuthentication can stay on.
2. Fast path: `kubectl delete virtualservice -A -l app.kubernetes.io/component=vps-egress`.
3. Do not use Helm rollback for this: the previous revision may still have VPS routing on.
4. Do not delete `istio-egressgateway`. Without a VirtualService, traffic never hits it.

Re-enable: confirm both VPS Envoy listeners, set `vpsEgress.enabled: true`, upgrade, then rollout-restart the matched Deployments so sidecars reload.

### Install sketch

```bash
# App namespace injection (after istiod from the mesh-eso kit)
kubectl label namespace app istio-injection=enabled

helm upgrade --install istio-peer-auth . \
  --namespace istio-system \
  --values values.yaml \
  --wait

helm upgrade --install istio-egressgateway istio/gateway \
  --namespace istio-system \
  --version 1.27.3 \
  --values values-egress-gateway.example.yaml

helm upgrade --install istio-vps-egress . \
  --namespace istio-system \
  --values values.yaml \
  --wait
```

Verify:

```bash
kubectl get peerauthentication -n app
kubectl get serviceentry,destinationrule,gateway -n istio-system -l app.kubernetes.io/component=vps-egress
kubectl get virtualservice -n app -l app.kubernetes.io/component=vps-egress
kubectl get virtualservice -n monitoring -l app.kubernetes.io/component=vps-egress
```

## Sanitize

[`../../SANITIZE.md`](../../SANITIZE.md). No live VPS IPs, no employer namespaces, no product release names, no alert-API FQDNs.

**Keywords:** Istio, PeerAuthentication, mTLS, egress gateway, ServiceEntry, DestinationRule, VirtualService, VPS proxy, Grafana
