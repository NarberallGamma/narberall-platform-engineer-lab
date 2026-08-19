# Platform: Selectel Cloud / OpenStack VPC

Selectel Cloud is OpenStack IaaS (Nova / Cinder / Neutron / Keystone). Providers: `selectel/selectel` + `openstack`.

| File | Resources |
|------|-----------|
| `network.tf` | Network, subnet, image data |
| `network_extra.tf` | Kube Neutron net, external network data |
| `kube.tf` / `purpose.tf` | Image-boot guests (bastion, kube, GitLab, Postgres, runner, Vault, Redis, monitor, proxy) |
| `volume_boot_kube.tf` | Volume-boot masters + bastion, AZ `ru-3a`/`ru-3b`, etcd disks, `fast.*` volume types |
| `postgres_ha.tf` | Anti-affinity pair, root + 850G data + WAL on `universal.*` |
| `gitlab_dualnic.tf` | Volume-boot GitLab on external + VPC |
| `volumes_sg.tf` | Extra volumes, SG, floating IP |
| `providers.tf` / `backend.tf` | Identity v3 + Selectel S3 state |

Dedicated Proxmox on Selectel HVs: [`../selectel/proxmox-dc/`](../selectel/proxmox-dc/).  
Experience: [`../../cloud/selectel.md`](../../cloud/selectel.md)  
Map: [`../RESOURCES.md`](../RESOURCES.md)
