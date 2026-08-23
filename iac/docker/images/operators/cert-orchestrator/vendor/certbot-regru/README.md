# certbot-regru

Reg.ru DNS authenticator plugin for [Certbot](https://certbot.eff.org/) — DNS-01 challenge for domains on REG.RU nameservers.

This copy is vendored into the **cert-orchestrator** repository. Upstream: `https://github.com/free2er/certbot-regru`.

## Requirements

- certbot (>=0.21.1)

## Installation (upstream)

```bash
sudo pip install certbot-regru
```

## Credentials

REG.RU credentials file (mode 600), for example `/etc/letsencrypt/regru.ini`:

```
certbot_regru:dns_username=...
certbot_regru:dns_password=...
```

## Usage

```bash
sudo certbot certonly -a certbot-regru:dns -d sub.domain.tld -d *.wildcard.tld
```

With Certbot 3.x the CLI plugin name is `dns` (see `certbot plugins`), flags: `-a dns`, `--dns-credentials`, `--dns-propagation-seconds` (prefix `dns-`, not `certbot-regru:`).

## Options

- `--dns-propagation-seconds` (Certbot 3.x; previously `--certbot-regru:dns-propagation-seconds`) — DNS wait (default 120)
- `--dns-credentials` (Certbot 3.x; previously `--certbot-regru:dns-credentials`) — path to INI (default `/etc/letsencrypt/regru.ini`)

## Removal

```bash
sudo pip uninstall certbot-regru
```
