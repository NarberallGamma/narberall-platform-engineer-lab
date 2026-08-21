# Fluent Bit sidecar (thin)

**Business first:** a shop indexer sidecar is **Fluent Bit and a config volume**, not a second logging stack. Kit: [`../`](../). Hub: [`../../../`](../../../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).

I kept this five-line file because that is the real compose. Image `fluent/fluent-bit:4.0.12-debug`. The bind is `./:/fluent-bit/etc`.

```text
fluent-bit-sidecar/
  docker-compose.yml    # fluent/fluent-bit:4.0.12-debug, volume ./ → /fluent-bit/etc
```

```bash
# from this directory, after a fluent-bit.conf (and parsers) sit in ./ :
docker compose up -d
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Five lines | Honest thin file, not a stub I wrote |
| Debug tag | Laptop sidecar, not a production distroless pin |
| Whole-dir volume | Config is the working tree |

## Honest gap

No `fluent-bit.conf` in this folder. The Helm-templated config that lived next to the source app is not Compose context. `docker compose up` starts the image; Fluent Bit exits or no-ops without a config.

**Keywords:** Fluent Bit, sidecar, 4.0.12, thin compose
