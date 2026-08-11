# Sanitize checklist (before publish)

- [ ] No secrets, tokens, private keys, `.env` with values  
- [ ] No client legal names (use sector + scale)  
- [ ] No real hostnames, IPs, internal domains  
- [ ] No ServiceDesk / wiki / Nextcloud URLs from client tenants  
- [ ] No home LAN details in home-lab docs  
- [ ] Configs are `*.example` only  
- [ ] Diagrams use generic labels  
- [ ] `gitleaks` / secret scan clean (when pre-commit enabled)  
