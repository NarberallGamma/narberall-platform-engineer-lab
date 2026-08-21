# OpenVPN admin compose (host)

**Business first:** the host-network admin UI is a **compose file with PKI bind-mounts**, next to the image and the Helm chart. Image: [`../../images/apps/ovpn-admin/`](../../images/apps/ovpn-admin/). Chart: [`../../../helm/reference/helm-addons-extra/openvpn-admin/`](../../../helm/reference/helm-addons-extra/openvpn-admin/). Sanitize: [`../../SANITIZE.md`](../../SANITIZE.md).

I used this on a box that already ran OpenVPN. The container is `network_mode: host`, mounts easy-rsa / ccd / `tc.key`, and renders client configs from the templates here. Admin password is `CHANGE_ME`. Endpoint is `203.0.113.10:1194:udp`. No PEM is in git. Not a public evasion guide.

```text
ovpn-admin/
  docker-compose.yaml
  .env.example
  templates/
    client.conf.tpl
    ccd.tpl
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Host network + host PKI paths | Different mechanic from the in-cluster Helm pod (`emptyDir` certs) |
| Templates with `{{ .Cert }}` | Placeholders only |
| Split from Helm | Chart is Kubernetes. This file is the host admin UI |

```bash
# place host PKI under /etc/openvpn/... (not in this repo)
# build ovpn-admin:local from images/apps/ovpn-admin (needs omitted frontend/Go)
cp .env.example .env
docker compose up -d
```

**Keywords:** OpenVPN, ovpn-admin, host network, easy-rsa
