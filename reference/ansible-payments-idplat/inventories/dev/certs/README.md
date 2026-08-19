# TLS artifacts (local only)

PFX / PEM files stay off git. Inventory expects these names next to this README:

- `am-hosting.pfx`
- `am-sign.pfx`
- `ig-hosting.pfx`
- `igext-hosting.pfx`
- `cert.pem` (CA bundle)
- DataProtection XML keys referenced from group_vars

Passwords live in `group_vars/all/passwd.yaml` (copy from `passwd.yaml.example`).
