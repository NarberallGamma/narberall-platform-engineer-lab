# certbot-regru

Reg.ru DNS authenticator plugin for [Certbot](https://certbot.eff.org/) — DNS-01 challenge for domains on REG.RU nameservers.

Эта копия входит в репозиторий **cert-orchestrator** (вендоринг). Апстрим: `https://github.com/free2er/certbot-regru`.

## Requirements

- certbot (>=0.21.1)

## Installation (upstream)

```bash
sudo pip install certbot-regru
```

## Credentials

Файл с учётными данными REG.RU (права 600), например `/etc/letsencrypt/regru.ini`:

```
certbot_regru:dns_username=...
certbot_regru:dns_password=...
```

## Usage

```bash
sudo certbot certonly -a certbot-regru:dns -d sub.domain.tld -d *.wildcard.tld
```

При Certbot 3.x имя плагина в CLI — `dns` (см. `certbot plugins`), флаги: `-a dns`, `--dns-credentials`, `--dns-propagation-seconds` (префикс `dns-`, не `certbot-regru:`).

## Options

- `--dns-propagation-seconds` (Certbot 3.x; ранее `--certbot-regru:dns-propagation-seconds`) — ожидание DNS (default 120)
- `--dns-credentials` (Certbot 3.x; ранее `--certbot-regru:dns-credentials`) — путь к INI (default `/etc/letsencrypt/regru.ini`)

## Removal

```bash
sudo pip uninstall certbot-regru
```
