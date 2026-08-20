# Estate NOTES (not copied)

Wildcard TLS on this estate was **DNS-01 -> certbot -> Kubernetes Secret**. Host and registrar scripts are not in this kit.

A later apps pass covers the global ExternalSecret generator (one Vault path merged into every app). That is not cluster Helm.

CI install jobs install infra (operators, this Vault wrap, ESO, ingress, Argo). Argo ships the application repos.
