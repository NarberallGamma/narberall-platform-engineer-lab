# Existing CCE / RDS / ECS IDs for import. No resources declared in this module.
# NGFW ECS is already in Terragrunt live/ngfw and must stay there.

variable "cce_ids" {
  description = "Existing CCE cluster IDs (not in live/)."
  type        = map(string)
  default = {
    dev     = "00000000-0000-4000-8000-000000000301"
    preprod = "00000000-0000-4000-8000-000000000302"
    prod    = "00000000-0000-4000-8000-000000000303"
  }
}

variable "rds_ids" {
  description = "Existing RDS PostgreSQL instance IDs (not in live/)."
  type        = map(string)
  default = {
    prod    = "00000000000000000000000000000001in03"
    preprod = "00000000000000000000000000000002in03"
    dev     = "00000000000000000000000000000003in03"
  }
}

variable "ecs_ids" {
  description = "Standalone ECS IDs that are not in live/."
  type        = map(string)
  default = {
    gitlab_dev        = "00000000-0000-4000-8000-000000000401"
    gitlab_prod       = "00000000-0000-4000-8000-000000000402"
    vault_dev         = "00000000-0000-4000-8000-000000000403"
    vault_prod        = "00000000-0000-4000-8000-000000000404"
    appsec_nessus     = "00000000-0000-4000-8000-000000000405"
    appsec_semgrep    = "00000000-0000-4000-8000-000000000406"
    appsec_dtrack     = "00000000-0000-4000-8000-000000000407"
    appsec_defectdojo = "00000000-0000-4000-8000-000000000408"
    ecs_test_prod     = "00000000-0000-4000-8000-000000000409"
    ecs_test_preprod  = "00000000-0000-4000-8000-000000000410"
  }
}

variable "do_not_import" {
  description = "Already managed in Terragrunt live/*. Do not declare as resource here."
  type        = map(string)
  default = {
    ngfw_ecs            = "00000000-0000-4000-8000-000000000801"
    ngfw_eip_untrust    = "00000000-0000-4000-8000-000000000802"
    preprod_eip         = "00000000-0000-4000-8000-000000000803"
    ngfw_vip_trust      = "00000000-0000-4000-8000-000000000804"
    ngfw_vip_untrust    = "00000000-0000-4000-8000-000000000805"
    ngfw_route_table    = "00000000-0000-4000-8000-000000000806"
    network_live_repo   = "terragrunt-live-network"
    network_state_pfx   = "live/"
  }
}
