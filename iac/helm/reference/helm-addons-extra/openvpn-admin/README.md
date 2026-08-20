# OpenVPN admin (Helm)

**Business first:** staff VPN is a **charted admin UI**, not a forum how-to. Hub: [`../`](../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).

This slice is the in-cluster **staff VPN admin**: a Go/Vue UI that issues client certificates and routes, plus an OpenVPN server sidecar. PKI lives in `emptyDir` and is created at runtime. No CA, server key, or client bundle is in this tree.

It is not a public evasion guide. Inlet defaults to HostPort 1194. Ingress (off by default) is basic-auth in front of the admin UI only.

```text
openvpn-admin/
  Chart.yaml                # 0.0.3, app 2.0.2
  values.yaml
  templates/
    deployment.yaml         # ovpn-admin + openvpn, NET_ADMIN, certs emptyDir
    configmap.yaml          # server.conf + entrypoint wait-for-PKI
    service.yaml            # headless admin; LB / ExternalIP / HostPort inlet
    ingress.yaml
    rbac.yaml               # Role may manage Secrets (runtime client certs)
    secret.yaml             # basic-auth from values
```

Upstream images: `ghcr.io/palark/ovpn-admin`. Chart source: https://github.com/palark/openvpn-admin

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Two-container pod | Admin UI talks to OpenVPN management on localhost; certs shared on emptyDir |
| Inlet switch | HostPort, LoadBalancer, or ExternalIP from one values key |
| RBAC | Admin stores client material in Kubernetes Secrets. Live PEMs are not shipped |
| Ingress | Optional basic-auth on the UI host (`vpn-admin.example.com`) |

## What is not in git

- Runtime PKI (`ca.crt`, `server.key`, `dh.pem`, client bundles)
- Image build context (frontend/Go Dockerfiles)
- Any backup tarball of a live VPN

**Keywords:** OpenVPN, ovpn-admin, Helm, staff VPN, easy-rsa
