# CI image: helm + helmfile + helm-diff (+ optional kubectl).
# Base: alpine/helm 3.18.6

FROM alpine/helm:3.18.6

ARG HELMFILE_VERSION=0.169.1
# Empty = no kubectl (baseline tag). Example: v1.34.3
ARG KUBECTL_VERSION=

RUN apk add --no-cache curl bash git \
 && helm plugin install https://github.com/databus23/helm-diff \
 && curl -fsSL -o /tmp/helmfile.tar.gz \
      "https://github.com/helmfile/helmfile/releases/download/v${HELMFILE_VERSION}/helmfile_${HELMFILE_VERSION}_linux_amd64.tar.gz" \
 && tar -xzf /tmp/helmfile.tar.gz -C /tmp/ \
 && mv /tmp/helmfile /usr/local/bin/helmfile \
 && chmod +x /usr/local/bin/helmfile \
 && rm -f /tmp/helmfile.tar.gz \
 && if [ -n "${KUBECTL_VERSION}" ]; then \
      curl -fsSL -o /usr/bin/kubectl \
        "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
      && chmod +x /usr/bin/kubectl; \
    fi

WORKDIR /apps

# GitLab CI runs /bin/sh scripts; reset helm entrypoint from base image.
ENTRYPOINT []
CMD ["/bin/sh"]
