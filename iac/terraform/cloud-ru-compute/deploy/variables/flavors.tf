variable "flavors" {
  description = "Flavor name/id catalog (ECS, CCE, RDS)"
  type        = map(string)
  default = {
    s7n_2xlarge_2         = "s7n.2xlarge.2"
    s7n_large_2           = "s7n.large.2"
    s7n_medium_2          = "s7n.medium.2"
    c6nl_xlarge_2         = "c6nl.xlarge.2"
    c7n_xlarge_2          = "c7n.xlarge.2"
    c3_2xlarge_2          = "c3.2xlarge.2"
    c7n_2xlarge_4         = "c7n.2xlarge.4"
    cce_s1_small          = "cce.s1.small"
    cce_s2_small          = "cce.s2.small"
    rds_pg_n1_xlarge_4_ha = "rds.pg.n1.xlarge.4.ha"
    rds_pg_x1_xlarge_4_ha = "rds.pg.x1.xlarge.4.ha"
    rds_pg_x1_xlarge_4    = "rds.pg.x1.xlarge.4"
  }
}
