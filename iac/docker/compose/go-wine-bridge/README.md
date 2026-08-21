# Go + Wine bridge compose

**Business first:** the Wine gRPC server is one compose service on **50051**. Image kit: [`../../images/apps/go-wine-bridge/`](../../images/apps/go-wine-bridge/). Sanitize: [`../../SANITIZE.md`](../../SANITIZE.md).

```text
go-wine-bridge/
  docker-compose.yaml   # build Dockerfile.go_build, command: server
```

`build.context` is `..` and `dockerfile` is `./docker/Dockerfile.go_build` as in the original app tree (`docker/` next to Go sources). In this lab the three Dockerfiles live under `images/apps/go-wine-bridge/`.

**This stack will not build.** The vendor DLL and the Go tree are not in git. See the image README.

```bash
# still fails: missing DLL and sources
docker compose up
```

**Keywords:** Wine, gRPC, docker compose
