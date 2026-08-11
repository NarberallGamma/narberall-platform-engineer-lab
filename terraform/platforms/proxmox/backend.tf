# Example: GitLab HTTP backend (URL is fake; wire real project in private CI).
terraform {
  backend "http" {
    address        = "https://gitlab.example.com/api/v4/projects/0/terraform/state/proxmox"
    lock_address   = "https://gitlab.example.com/api/v4/projects/0/terraform/state/proxmox/lock"
    unlock_address = "https://gitlab.example.com/api/v4/projects/0/terraform/state/proxmox/lock"
    lock_method    = "POST"
    unlock_method  = "DELETE"
    retry_wait_min = 5
    username       = "gitlab-ci-token"
  }
}
