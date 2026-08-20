# Helmfile DEV stand

**Business first:** a DEV namespace is **two helmfiles and local charts**, not one Argo Application list. Hub: [`../../`](../../). Sanitize: [`../../SANITIZE.md`](../../SANITIZE.md). Buyer page: [`../../../../docs/for-business.md`](../../../../docs/for-business.md). Case: [`../../../../case-studies/11-helm-estate.md`](../../../../case-studies/11-helm-estate.md).

I composed this stand when product charts lived in two repos and CI applied each helmfile on its own. Both files target the same namespace (`dev-stand`). One side is an in-cluster LLM API with a models PVC. The other is an HTTP feed API plus the same RSS CronJob chart released three times with a one-minute schedule shift.

This folder is the only helmfile SAMPLE in the lab. Full Istio install trees are in [`../../reference/helm-mesh-eso/`](../../reference/helm-mesh-eso/), not here.

```text
helmfile-dev/
  README.md
  stands/
    dev-stand-llm/
      helmfile.yaml              # one release: llm-api
      values.yaml                # namespace, PVC, optional hostAliases
      llm-api.env.yaml           # image pin
    dev-stand-feed/
      helmfile.yaml              # feed-api + three feed-rss releases
      values-feed-api.yaml       # env + example Secret keys
      values-feed-rss.yaml       # shared PVC size
  charts/
    llm-api/                     # Deployment + NodePort + models PVC
    feed-api/                    # Deployment + ClusterIP + memory PVC + optional Secret
    feed-rss/                    # CronJob + per-release PVC
```

Render a chart without helmfile:

```bash
helm template llm-api charts/llm-api --namespace dev-stand
helm template feed-api charts/feed-api -f stands/dev-stand-feed/values-feed-api.yaml --namespace dev-stand
helm template feed-rss-alpha charts/feed-rss -f stands/dev-stand-feed/values-feed-rss.yaml --namespace dev-stand
# Staggered schedule and rssSource overlays live in stands/dev-stand-feed/helmfile.yaml (inline values).
```

Apply the stand (helmfile 0.169.x, Helm 3.18.x as used in CI):

```bash
helmfile apply -f stands/dev-stand-llm/helmfile.yaml
helmfile apply -f stands/dev-stand-feed/helmfile.yaml
```

Namespace `dev-stand` is created outside these files (`createNamespace: false` on the feed side).

## Who this page is for

Hiring lead: this is one DEV composition pattern, not a product farm. Engineer: the unique mechanic is helmfile inline values on a repeated CronJob chart, plus a second helmfile for the LLM PVC.

## What this kit is / is not

It is two local-chart helmfiles that share a namespace. It is not an Istio install, not a branded agent gateway, not a Telegram bot, and not an Argo Application.

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Two helmfiles, one namespace | Product charts lived in two repos. CI ran `helmfile apply -f` twice against `dev-stand` |
| Local `chart:` paths | No helm repo, no OCI. `../../charts/<name>` from each stand |
| Inline values on RSS | Same chart, several releases. `schedule` and `rssSource` overlay the shared file |
| Staggered CronJobs | Minute shift (0 / 1 / 2) so five-minute pollers do not start together. `concurrencyPolicy: Forbid` |
| llm-api NodePort + PVC | DEV access on :11434. Models stay on a 50Gi volume (`OLLAMA_MODELS`) |
| feed-api Secret from values | Per-stand keys are b64-encoded in the chart. Live tokens stay out. This is weaker than ESO |
| Optional hostAliases | DEV stand could reach a private git / registry with no cluster DNS. Placeholders only |

## Two helmfiles

The live estate applied an LLM/infra helmfile from one repo and a feed helmfile from another. I keep that split.

`dev-stand-llm` ships `llm-api` only. The live file also listed a mesh adjunct, a fleet watcher, and two product gateways. Those stay out (see SKIP).

`dev-stand-feed` ships `feed-api` plus three `feed-rss` releases. The live file had five branded news sources. Three generic sources are enough to show the stampede-avoidance overlay. A Telegram bridge and a webhook-retry CronJob were extra product and stay out.

## llm-api

Thin chart. Deployment, NodePort Service, models PVC. Templates still take `k8s_namespace` from values (this family did not rely on Helm release namespace alone).

`hostAliases` and `imagePullSecrets` are values-driven. The live chart hardcoded a private registry IP and a named pull secret. Those are stripped.

The live stand layered an unused `existingClaim` and an unused mesh values file. The chart never read `existingClaim`. I dropped both.

## feed-api + feed-rss

`feed-api` is a ClusterIP on :8400 with `/health` probes, a memory PVC, and an optional Secret. `fullname` is the release name (truncated). Helpers set `app.kubernetes.io/name` to that same fullname, so selectors stay aligned with a helmfile release rename.

`feed-rss` is a CronJob (`python3 rss_poller.py --source <rssSource>`), 120s deadline, `backoffLimit: 1`. Each release gets its own 100Mi PVC. That is wasteful and honest: the live stand did the same.

Secrets in helmfile values are a pattern I do **not** recommend next to the estate ESO kits. I keep the template so a reviewer can see how the DEV stand actually injected callback URLs. Keys here are documentation-range HTTP URLs only.

## SKIP (not in this folder)

| Source | Why it stays out |
|--------|------------------|
| Mesh adjunct chart (`Service` ExternalName + `Endpoints`) | Not an Istio install. Full `base` + `istiod` is [`../../reference/helm-mesh-eso/`](../../reference/helm-mesh-eso/) |
| Branded agent gateway (two chart variants) | Product name plus live API / gateway tokens in ConfigMap and Secret. One variant used `.Files.Get` for JSON. That mechanic already exists on the PKI overlay |
| Fleet watcher | Thin clone of Deployment + PVC + ConfigMap `.env`. Same hostAliases family as llm-api. ConfigMap held live tokens |
| Telegram bridge chart | Same helpers as feed-api. Stand values held a bot token |
| Webhook-flush CronJob | Thin job that reused the API PVC and Secret. No new mechanic |
| GitLab runner manifests | Docker-socket runner, not a helmfile product chart |
| Helmfile CI image Dockerfile | Pin only: helmfile **0.169.1**, Helm **3.18.6**, kubectl 1.34.x. Image lives in cluster-resources, not this SAMPLE |

## Sanitize

Hosts are `*.example.com`. Images are `example.registry/apps/...`. Namespace is `dev-stand`. Callback URLs use `203.0.113.10`. hostAliases use `10.10.4.10`. No PEM, no pull-secret name from the live cluster, no `secret-values.yaml`, no Argo Application.

**Keywords:** helmfile, Helm, CronJob, staggered schedule, Ollama, NodePort, PVC, local chart, DEV stand
