# Kubernetes CI runner

**Business first:** the job pod already has kubectl, Helm, and the estate chart repos. Writing kubeconfig and image-pull secrets is a script, not a ticket.

I used this image on Kubernetes-backed GitLab runners. `init.sh` writes a token kubeconfig from `KUBE_SERVER` / `KUBE_TOKEN`. `create-regcred.sh` upserts `docker-registry` secrets (`regcred`, optional `external-regcred`, `gitlab-regcred`) across a comma-separated namespace list.

The Docker-login sibling is [`../base-runner-docker/`](../base-runner-docker/). Different mechanic.

```text
base-runner-k8s/
  Dockerfile
  init.sh
  create-regcred.sh
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| kubectl + Helm 3 | Install at image build, not on each job |
| Helm repos baked | argo, strimzi, external-secrets, prometheus-community, ingress-nginx, istio |
| `create-regcred.sh` | Three registry classes, skip when creds are unset |
| Token kubeconfig | CI payload, not a checked-in kubeconfig |

```bash
docker build -t example.registry/ci/base-runner-k8s:alpine -f Dockerfile .
```

Honest gap: `init.sh` sets `insecure-skip-tls-verify: true`. That is the living habit from the estate job, not a recommendation.

Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).
