# Embedding certbot-regru into cert-orchestrator

Upstream plugin: **certbot-regru** (Reg.ru DNS-01 for Certbot), MIT License, see `LICENSE.txt`.

This directory is a **vendored copy** for building the `cert-orchestrator` image without an external repository.

Differences from upstream:

- `setup.py` does not install `regru.ini` into `/etc/letsencrypt` on `pip install`. At runtime cert-orchestrator can build the INI from the main YAML (`letsencrypt.regru`) or use a mounted file via `regru_ini_path`.
- Credentials example: `regru.ini.example`.

Updating from upstream: replace files under `certbot_regru/` and, if needed, `setup.py`, while keeping the changes above.
