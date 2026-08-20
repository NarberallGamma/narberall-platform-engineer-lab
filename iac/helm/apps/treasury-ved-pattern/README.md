# Estate app pattern (CryptoPro slice)

Thin umbrellas over `_libs/base-chart`. I added the three CryptoPro PVC samples. Hub: [`../../`](../../). Sanitize: [`../../SANITIZE.md`](../../SANITIZE.md).

| Dir | Mechanic |
|-----|----------|
| [`policy-gateway/`](policy-gateway/) | 1 PVC lookup/keep + `_initcontainers.tpl` |
| [`pki-gateway/`](pki-gateway/) | 3 PVC (users / keys / pkidebug) + `.Files.Get` |
| [`cryptopro/`](cryptopro/) | thin `cprocsp` PVC + keep, no bootstrap |

cert-verifier is not here. Sibling umbrellas (auth, operator UI, gRPC, websocket, static site, monolith) are separate samples.
