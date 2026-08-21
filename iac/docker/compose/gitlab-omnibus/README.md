# GitLab Omnibus (DEV + PROD)

**Business first:** GitLab on the host is **Omnibus plus a front nginx**, not an Ansible template of nginx alone. Hub: [`../../`](../../). Sanitize: [`../../SANITIZE.md`](../../SANITIZE.md). Estate front-only sibling: [`../../../ansible/reference/ansible-estate/roles/docker_app/templates/gitlab-nginx/`](../../../ansible/reference/ansible-estate/roles/docker_app/templates/gitlab-nginx/).

I used this pair on two VMs: DEV `gitlab/gitlab-ee:19.0.1-ee.0` and PROD `19.1.2-ee.0`. Same topology: Omnibus HTTP :80 behind nginx TLS, container registry :5050, git SSH :7999, SAML + LDAP, Pages off, object-storage backup. SMTP, LDAP bind, and S3 keys stay `CHANGE_ME`. License key, TLS, and data dirs stay out of git.

```text
gitlab-omnibus/
  docker-compose.dev.yml      # EE 19.0.1, git-dev.example.com, DEV LDAP DN/groups
  docker-compose.prod.yml     # EE 19.1.2, git.example.com, PROD LDAP DN/groups
  git-dev.example.com.conf    # front nginx: HTTP→HTTPS, Pages wildcard
  git.example.com.conf
  .env.example                # documents Omnibus secrets; compose does not load this file
```

```bash
# from this directory, after local config/, data/, logs/, ssl/, and public.key exist:
docker compose -f docker-compose.dev.yml up -d
docker compose -f docker-compose.prod.yml up -d
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Full `GITLAB_OMNIBUS_CONFIG` | SAML ACS, LDAP `simple_tls` :636, registry path, backup to `s3.example.com` |
| DEV vs PROD files | Image pin, hostname, bind DN, `admin_group`, Pages URL. Not one compose with an env switch |
| Front nginx | Host :80/:443. Omnibus listens HTTP. Trusted proxy `10.10.103.0/24` |
| Registry :5050 + SSH :7999 | Published next to HTTPS, not folded into 443 |
| Commented `backup` sidecar | rclone + docker.sock lived on the host. Left as a comment, not a second product |
| `.env.example` | SMTP / LDAP / S3 / SAML fingerprint placeholders. Values in the YAML stay `CHANGE_ME` |

This is **not** [`../../../ansible/reference/ansible-estate/roles/docker_app/templates/gitlab-nginx/`](../../../ansible/reference/ansible-estate/roles/docker_app/templates/gitlab-nginx/). That role is host-network nginx in front of GitLab. This folder is the Omnibus container plus that front.

## Honest gap

`./config`, `./data`, `./logs`, `./ssl`, and `./public.key` are not in git. Compose will not stay up without them. Pages stay disabled (`gitlab_pages['enable'] = false`) while `pages_external_url` is still set. An older host compose filename existed on the VM; the body was never captured.

**Keywords:** GitLab EE Omnibus, SAML, LDAP, container registry, nginx front, S3 backup
