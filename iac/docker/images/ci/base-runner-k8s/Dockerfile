FROM alpine:3.22.1

RUN apk add --no-cache curl bash openssl git rsync jq && \
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    chmod +x kubectl && \
    mv kubectl /usr/local/bin/ && \
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 && \
    chmod 700 get_helm.sh && \
    ./get_helm.sh && \
    rm get_helm.sh && \
    mkdir -p /root/.kube && \
    helm repo add argo https://argoproj.github.io/argo-helm && \
    helm repo add strimzi https://strimzi.io/charts/ && \
    helm repo add external-secrets https://charts.external-secrets.io && \
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts && \
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx && \
    helm repo add istio https://istio-release.storage.googleapis.com/charts && \
    helm repo update

COPY init.sh /usr/local/bin/init.sh
COPY create-regcred.sh /usr/local/bin/create-regcred.sh
RUN chmod +x /usr/local/bin/init.sh /usr/local/bin/create-regcred.sh
