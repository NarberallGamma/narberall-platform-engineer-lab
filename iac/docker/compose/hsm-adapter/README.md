# HSM adapter (CryptoPro volumes + host nginx)

**Business first:** signing material is unpacked once, then the adapter process stays up. I do not bake keys into the app image.

Sanitize: [`../../SANITIZE.md`](../../SANITIZE.md). Estate Ansible of the same stack (bind mounts + `env_file`): [`../../../ansible/reference/ansible-estate/roles/docker_app/templates/hsm-adapter/`](../../../ansible/reference/ansible-estate/roles/docker_app/templates/hsm-adapter/). Cluster CSP volumes: [`../../../helm/apps/treasury-ved-pattern/pki-gateway/`](../../../helm/apps/treasury-ved-pattern/pki-gateway/), thin claim: [`../../../helm/apps/treasury-ved-pattern/cryptopro/`](../../../helm/apps/treasury-ved-pattern/cryptopro/). Experience (HSM-adjacent VMs): [`../../../../docs/experience.md`](../../../../docs/experience.md).

This folder is **raw Compose**. Two registry pins, named volumes, a one-shot bootstrap, and a sibling host `nginx.conf`. There is **no application source** here. The Spring adapter and the bootstrap image are private binaries. CryptoPro archives (`keys.tar.gz`, `users.tar.gz`, `dsrf.tar.gz`) live inside the bootstrap image, not in git.

```text
hsm-adapter/
  docker-compose.yaml   # hsm-bootstrap (once) + hsm-adapter (8080 / 8081)
  nginx.conf            # host vhost, TLS, /hsm-adapter/ prefix strip
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| `hsm-bootstrap` | Init container unpacks CSP keys / users / dsrf into shared volumes, `chown 10001`, `restart: "no"`. |
| Named volumes | `hsm_keys`, `hsm_users`, `hsm_dsrf`, `hsm_tmp` at `/var/opt/cprocsp/…`. Same paths as the Helm PKI claims. |
| Split ports | App `8080`, management `8081` (`health,info,metrics,prometheus`). Healthcheck hits `/actuator/health` on 8081. |
| `EXTERNAL_CSP_LICENSE` | Placeholder `CHANGE_ME`. Substitute from a secret store when using ESO. |
| `nginx.conf` | Host sidecar, not a Compose service. HTTP→HTTPS, Swagger on `/`, prefix `/hsm-adapter/` stripped before `localhost:8080`. |

```bash
# place CSP license in the environment or a secret store (not in git)
docker compose up -d
# host nginx is a VM sidecar: install nginx.conf next to the unit, not via this compose file
```

## Honest gaps

- I cannot rebuild `example.registry/estate/hsm-adapter-app:2.8.0` or `hsm-bootstrap:0.1.0` from this kit. No JAR, no Dockerfile, no CSP tarballs.
- Ansible `docker_app` already has a **different** mechanic: `./data/…` bind mounts, `env_file`, Jinja image names, optional `8081`. This file is the service-repo compose with hardcoded tags and named volumes.
- Host nginx is legacy VM shape. It is not in `docker-compose.yaml`.
- CSP product paths (`cprouser`, `/var/opt/cprocsp`) stay. They are required by the image.

## Keywords

Docker Compose, HSM, CryptoPro, CSP, Spring Boot, nginx, named volumes, bootstrap init
