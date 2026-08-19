# Role-split kube node pools on Selectel-hosted Proxmox. Counts are a slice, not a full dump.
# telmate does not reject a colliding vmid/name; unique names are mandatory before apply.

module "kube_master" {
  source          = "./modules/guest"
  name_prefix     = "kube-master"
  count_vms       = 3
  hv_nodes        = var.hv_nodes
  clone_template  = var.clone_template
  storage         = var.storage
  ssh_public_key  = var.ssh_public_key
  desc            = "Ubuntu kube control"
  cores           = 8
  memory          = 16384
  disk_gb         = 50
  lan_ip_start    = 10
}

module "kube_worker" {
  source          = "./modules/guest"
  name_prefix     = "kube-worker"
  count_vms       = 3
  hv_nodes        = var.hv_nodes
  clone_template  = var.clone_template
  storage         = var.storage
  ssh_public_key  = var.ssh_public_key
  desc            = "Ubuntu kube worker"
  cores           = 16
  memory          = 32768
  disk_gb         = 50
  lan_ip_start    = 20
}

module "kube_frontend" {
  source          = "./modules/guest"
  name_prefix     = "kube-frontend"
  count_vms       = 3
  hv_nodes        = var.hv_nodes
  clone_template  = var.clone_template
  storage         = var.storage
  ssh_public_key  = var.ssh_public_key
  desc            = "Ubuntu kube frontend"
  cores           = 8
  memory          = 16384
  disk_gb         = 50
  lan_ip_start    = 30
}

module "kube_frontend_ws" {
  source          = "./modules/guest"
  name_prefix     = "kube-frontend-ws"
  count_vms       = 2
  hv_nodes        = var.hv_nodes
  clone_template  = var.clone_template
  storage         = var.storage
  ssh_public_key  = var.ssh_public_key
  desc            = "Ubuntu kube websocket"
  cores           = 4
  memory          = 8192
  disk_gb         = 50
  lan_ip_start    = 40
}

module "kube_sts" {
  source          = "./modules/guest"
  name_prefix     = "kube-sts"
  count_vms       = 3
  hv_nodes        = var.hv_nodes
  clone_template  = var.clone_template
  storage         = var.storage
  ssh_public_key  = var.ssh_public_key
  desc            = "Ubuntu kube stateful"
  cores           = 8
  memory          = 16384
  disk_gb         = 80
  lan_ip_start    = 50
}

module "kube_system" {
  source          = "./modules/guest"
  name_prefix     = "kube-system"
  count_vms       = 3
  hv_nodes        = var.hv_nodes
  clone_template  = var.clone_template
  storage         = var.storage
  ssh_public_key  = var.ssh_public_key
  desc            = "Ubuntu kube system"
  cores           = 4
  memory          = 8192
  disk_gb         = 50
  lan_ip_start    = 60
}

module "kube_logging" {
  source          = "./modules/guest"
  name_prefix     = "kube-logging"
  count_vms       = 3
  hv_nodes        = var.hv_nodes
  clone_template  = var.clone_template
  storage         = var.storage
  ssh_public_key  = var.ssh_public_key
  desc            = "Ubuntu kube logging"
  cores           = 8
  memory          = 16384
  disk_gb         = 100
  lan_ip_start    = 70
}

module "kube_isolated" {
  source          = "./modules/guest"
  name_prefix     = "kube-isolated"
  count_vms       = 3
  hv_nodes        = var.hv_nodes
  clone_template  = var.clone_template
  storage         = var.storage
  ssh_public_key  = var.ssh_public_key
  desc            = "Ubuntu kube isolated"
  cores           = 4
  memory          = 8192
  disk_gb         = 50
  lan_ip_start    = 80
}

module "kube_test" {
  source          = "./modules/guest"
  name_prefix     = "kube-test"
  count_vms       = 2
  hv_nodes        = var.hv_nodes
  clone_template  = var.clone_template
  storage         = var.storage
  ssh_public_key  = var.ssh_public_key
  desc            = "Ubuntu kube test"
  cores           = 4
  memory          = 8192
  disk_gb         = 50
  lan_ip_start    = 90
}

module "db_analytics" {
  source          = "./modules/guest"
  name_prefix     = "db-analytics"
  count_vms       = 1
  hv_nodes        = var.hv_nodes
  clone_template  = var.clone_template
  storage         = var.storage
  ssh_public_key  = var.ssh_public_key
  desc            = "Ubuntu analytics db"
  cores           = 8
  memory          = 32768
  disk_gb         = 100
  extra_disk_gb   = 500
  lan_ip_start    = 100
}

module "db_test" {
  source          = "./modules/guest"
  name_prefix     = "db-test"
  count_vms       = 2
  hv_nodes        = var.hv_nodes
  clone_template  = var.clone_template
  storage         = var.storage
  ssh_public_key  = var.ssh_public_key
  desc            = "Ubuntu test db"
  cores           = 4
  memory          = 8192
  disk_gb         = 80
  lan_ip_start    = 110
}

module "crons" {
  source          = "./modules/guest"
  name_prefix     = "crons"
  count_vms       = 2
  hv_nodes        = var.hv_nodes
  clone_template  = var.clone_template
  storage         = var.storage
  ssh_public_key  = var.ssh_public_key
  desc            = "Ubuntu cron workers"
  cores           = 4
  memory          = 8192
  disk_gb         = 50
  lan_ip_start    = 120
}

module "search" {
  source          = "./modules/guest"
  name_prefix     = "search"
  count_vms       = 2
  hv_nodes        = var.hv_nodes
  clone_template  = var.clone_template
  storage         = var.storage
  ssh_public_key  = var.ssh_public_key
  desc            = "Ubuntu search index"
  cores           = 2
  memory          = 8192
  disk_gb         = 50
  lan_ip_start    = 130
}

module "ceph" {
  source          = "./modules/guest"
  name_prefix     = "ceph"
  count_vms       = 3
  hv_nodes        = var.hv_nodes
  clone_template  = var.clone_template
  storage         = var.storage
  ssh_public_key  = var.ssh_public_key
  desc            = "Ubuntu ceph osd"
  cores           = 4
  memory          = 8192
  disk_gb         = 15
  extra_disk_gb   = 200
  extra_disk2_gb  = 200
  lan_ip_start    = 140
}
