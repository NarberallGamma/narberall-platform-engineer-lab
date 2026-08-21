# GitHub Actions publish trio

**Business first:** the same publish and gate habit on GitHub Actions: werf export on a tag, Helm chart-testing plus KinD, and a Go release matrix.

I used these when the repo was on GitHub, not GitLab. The public `ovpn-admin` binary name matches the lab Docker kit. This folder is the workflow include. The Dockerfile and compose file stay under Docker.

Hunter map: [`../`](../). CI hub: [`../../README.md`](../../README.md). GitLab werf sibling: [`../werf-delivery/`](../werf-delivery/). Image: [`../../../docker/images/apps/ovpn-admin/`](../../../docker/images/apps/ovpn-admin/). Compose: [`../../../docker/compose/ovpn-admin/`](../../../docker/compose/ovpn-admin/). Jenkins sibling: [`../jenkins/`](../jenkins/). Sanitize: [`../../SANITIZE.md`](../../SANITIZE.md).

```text
github-actions/
  werf-publish.yml.example    # werf build on PR, werf export on tag / main
  chart-test.yml.example      # Helm ct lint + KinD install matrix
  go-release.yml.example      # Go binary matrix (linux/386 + amd64)
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| `werf-publish.yml.example` | `werf/actions/install@v2`, QEMU for four platforms, `werf cr login` to `example.registry`, `werf build` on pull request and `werf export` on tag or `master`. Registry host stays generic. Token stays in GitHub secrets. |
| `chart-test.yml.example` | `helm/chart-testing-action`: `ct lint`, generated-docs check, then `ct install` on KinD for Kubernetes 1.25 / 1.29 / 1.31. Node image pins are upstream `kindest` digests. |
| `go-release.yml.example` | Release-only matrix (`linux` × `386`/`amd64`) via `go-release-action`, Go 1.23, `build.sh` / `install-deps.sh`, binary name `ovpn-admin`. |

```bash
# copy into .github/workflows/ of the app repo and drop the .example suffix
# werf.yaml, charts, build.sh, and install-deps.sh stay in that app tree
```

This is a different include from the lab Docker `ovpn-admin` image and compose. Those folders are the build context and the host stack. These three files are the GitHub Actions wiring.

## Honest gaps

- No GitLab twin in this folder. GitLab werf kits live in sibling folders.
- Chart-releaser and the arm/arm64 Go twin are not published. One richest file per mechanic.
- `werf.yaml`, Helm charts, `build.sh`, and `install-deps.sh` are not here. The workflows expect them in the application repo.
- No OSV-Scanner job. No Jenkinsfile in this folder (that controller is the sibling kit).
