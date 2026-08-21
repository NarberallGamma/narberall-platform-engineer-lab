# OpenVPN admin (image)

**Business first:** staff VPN admin is a **built Go/Vue binary**, not only a Helm wrapper around a public image. Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md). Host compose: [`../../../compose/ovpn-admin/`](../../../compose/ovpn-admin/). Chart already in lab: [`../../../../helm/reference/helm-addons-extra/openvpn-admin/`](../../../../helm/reference/helm-addons-extra/openvpn-admin/).

The Helm README said the image build context was not in git. This folder is that **image half**: Node 16 frontend, Go 1.24 + packr2, Alpine 3.18 with easy-rsa / openvpn / `openvpn-user`. Frontend and Go sources stay out. PKI stays out. This is not a public evasion guide.

```text
ovpn-admin/
  Dockerfile.ovpn-admin   # three stages: frontend, packr2/Go, Alpine runtime
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Three stages | npm build → packr2 embed → static `ovpn-admin` on Alpine |
| `TARGETARCH` | `GOARCH` plus the `openvpn-user` tarball name |
| easy-rsa + openvpn in the image | Host compose bind-mounts PKI; the binary still needs the tools |
| Split from Helm | Chart is the in-cluster pod. This file is the build I actually ran |

`COPY ../frontend` and `COPY ..` expect the omitted app tree (frontend + Go) as the parent of the Docker context. `docker build` fails without it. Live `ca.key` / `server.key` / backup tarball were never copied.

```bash
# from the omitted app tree, context is the parent of kubernetes/
docker build -f Dockerfile.ovpn-admin -t ovpn-admin:local ..
```

**Keywords:** OpenVPN, ovpn-admin, packr2, easy-rsa, staff VPN
