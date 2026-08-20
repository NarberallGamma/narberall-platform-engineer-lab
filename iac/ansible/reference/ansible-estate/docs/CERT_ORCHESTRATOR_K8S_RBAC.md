# cert-orchestrator: K8s RBAC и токен

Выполнять на **GitLab control node** с рабочим `kubectl` (preprod: `estate-preprod-gitlab`, prod: `estate-prod-gitlab`).

Оркестратор ходит в API по `kubernetes.api_server` + `K8S_TOKEN` + CA (`k8s_ca_cert` в Vault). Список namespace: `cert_orchestrator_k8s_namespace_secrets` в `group_vars/cert-orchestrator.yml`.

## 1. Манифест

Файл `/tmp/cert-orchestrator-rbac.yaml`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: cert-orchestrator
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cert-orchestrator
  namespace: cert-orchestrator
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cert-orchestrator-tls-secrets
rules:
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get", "list", "create", "update", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cert-orchestrator-tls-secrets
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cert-orchestrator-tls-secrets
subjects:
  - kind: ServiceAccount
    name: cert-orchestrator
    namespace: cert-orchestrator
---
apiVersion: v1
kind: Secret
metadata:
  name: cert-orchestrator-token
  namespace: cert-orchestrator
  annotations:
    kubernetes.io/service-account.name: cert-orchestrator
type: kubernetes.io/service-account-token
```

```bash
kubectl apply -f /tmp/cert-orchestrator-rbac.yaml
```

Проверка:

```bash
kubectl auth can-i patch secrets/wildcard-tls \
  --as=system:serviceaccount:cert-orchestrator:cert-orchestrator \
  -n platform
```

## 2. Токен и CA в Vault

```bash
kubectl get secret cert-orchestrator-token -n cert-orchestrator \
  -o jsonpath='{.data.token}' | base64 -d; echo

kubectl config view --raw \
  -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' \
  | base64 -d > /tmp/k8s-ca.crt
```

Preprod:

```bash
export VAULT_ADDR=https://vault.preprod.example.com
vault kv patch ansible/cert-orchestrator \
  K8S_TOKEN="$(kubectl get secret cert-orchestrator-token -n cert-orchestrator -o jsonpath='{.data.token}' | base64 -d)" \
  k8s_ca_cert=@/tmp/k8s-ca.crt
```

Prod (на `estate-prod-gitlab`, свой kube context):

```bash
export VAULT_ADDR=https://vault.example.com
vault kv patch ansible/cert-orchestrator \
  K8S_TOKEN="$(kubectl get secret cert-orchestrator-token -n cert-orchestrator -o jsonpath='{.data.token}' | base64 -d)" \
  k8s_ca_cert=@/tmp/k8s-ca.crt
```

## 3. Redeploy orchestrator

```bash
cd /ansible && source .env.vault
./scripts/run/run_docker_app.sh deploy cert-orchestrator --preprod --limit estate-preprod-gitlab
# prod:
# ./scripts/run/run_docker_app.sh deploy cert-orchestrator --prod --limit estate-prod-gitlab
```

## Примечания

- Secret `kubernetes.io/service-account-token`: токен без срока, пока Secret не удалён (legacy, для automation).
- Bound token (если нужен): `kubectl create token cert-orchestrator -n cert-orchestrator --duration=8760h`
- См. также: `DOCKER_APPS_VAULT_SECRETS.md`
