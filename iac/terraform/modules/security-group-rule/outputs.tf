/*
output "sg_rule_ids" {
  value = { for rule in sbercloud_networking_secgroup_rule.this : rule.key => rule.id }
}
*/

output "sg_rule_ids" {
  value = {
    for rule_key, rule in sbercloud_networking_secgroup_rule.this : rule_key => rule.id
  }
}
