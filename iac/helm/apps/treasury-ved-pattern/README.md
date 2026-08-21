# Estate product mechanics

Nine umbrellas over `_libs/base-chart` and `_libs/front-base`. One richest copy per mechanic, not a thirty-service farm. Hub: [`../`](../). Sanitize: [`../../SANITIZE.md`](../../SANITIZE.md).

| Dir | Mechanic |
|-----|----------|
| [`estate-auth/`](estate-auth/) | Auth service + Vault ExternalSecret |
| [`operator-ui/`](operator-ui/) | Operator UI overlay |
| [`policy-gateway/`](policy-gateway/) | 1 PVC lookup/keep + `_initcontainers.tpl` |
| [`pki-gateway/`](pki-gateway/) | 3 PVC (users / keys / pkidebug) + `.Files.Get` |
| [`cryptopro/`](cryptopro/) | Thin `cprocsp` PVC + keep, no bootstrap |
| [`contract-grpc/`](contract-grpc/) | gRPC Service + ExternalSecret |
| [`web-ws/`](web-ws/) | Websocket front over `front-base` |
| [`web-site/`](web-site/) | Remote-repo static site |
| [`estate-monolith/`](estate-monolith/) | Monolith overlay + Kafka PodMonitor |
| [`integration-secret/`](integration-secret/) | Integration ExternalSecret (text vs binary split) |

Shared libs stay under [`_libs/`](_libs/). Cluster envelope (mesh, ESO install, Argo) stays in [`../../reference/helm-estate-cluster/`](../../reference/helm-estate-cluster/).
