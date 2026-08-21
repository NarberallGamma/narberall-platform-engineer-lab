# Go + Wine market bridge

**Business first:** a Windows-only vendor DLL sits behind a **gRPC server under Wine**, not a rewrite of the vendor stack. Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md). Compose: [`../../../compose/go-wine-bridge/`](../../../compose/go-wine-bridge/).

I kept all three Dockerfiles. They are different mechanics, not twins: binary-only Alpine, Go 1.19 mingw cross on Alpine, and the same cross on Ubuntu 22.04 with `wine64`. Compose builds `Dockerfile.go_build` and exposes 50051.

```text
go-wine-bridge/
  Dockerfile                  # Alpine + Wine, wget a GitHub release tarball, COPY DLL
  Dockerfile.go_build         # golang:1.19-alpine mingw → .exe, Alpine + wine
  Dockerfile.go_build_ubuntu  # same builder, ubuntu:22.04 + wine64
  entrypoint.sh               # wine64 … server.exe
  entrypoint_ubuntu.sh        # wine64-stable … server.exe
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Three files | Release-tarball runtime vs in-tree mingw vs Ubuntu Wine |
| `GOOS=windows` + mingw CC | Static `.exe` from Linux CI |
| `TC_DLL_PATH` | Entrypoint hands the vendor DLL to Wine |
| `github.com/example/market-bridge` | Module path is already generic |

## What is not in git

- The vendor `market-bridge64.dll` (proprietary). Every Dockerfile `COPY`s it.
- Go sources (`main.go`, `client/`, `server/`, `proto/`, `go.mod`)

**This image will not build as published.** That gap is intentional.

```bash
# still fails: missing DLL and Go tree
docker build -t example.registry/market-bridge:local -f Dockerfile.go_build .
```

**Keywords:** Go, mingw, Wine, gRPC, vendor DLL
