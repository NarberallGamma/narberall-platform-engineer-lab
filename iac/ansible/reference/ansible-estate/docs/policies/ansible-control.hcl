# Policy ansible-control: GitLab CI token для ansible control node
# Mount ansible/ (docker apps: cert-*, cloud-hibernate) + secret/ (hsm-adapter и др.)

path "ansible/data/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "ansible/metadata/*" {
  capabilities = ["list", "read", "delete"]
}

path "secret/data/*" {
  capabilities = ["read", "list"]
}
path "secret/metadata/*" {
  capabilities = ["read", "list"]
}
