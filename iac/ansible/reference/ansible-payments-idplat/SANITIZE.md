# Sanitize notes (this tree)

What was removed or rewritten before publish:

- Vendor / employer brand strings and AD DNS
- Inventory user and password
- Private registry host:port
- Lab Swarm hostname
- Live `passwd.yaml` (replaced by `passwd.yaml.example` with `CHANGE_ME`)
- PFX / PEM / DataProtection XML key files
- LDAP bind password and SMTP channel ciphertext in realm samples

What stayed (on purpose):

- Role graphs, Jinja, Swarm wait loops, k8s templates
- Realm JSON / YAML shapes (OIDC, JWT, LDAP, Windows modules)
- YARP reverse-access, metrics, and tracing samples
- Russian operator comments inside roles (original autodeploy language)

Do not add real certificates, hashes, or connection strings back into git.
