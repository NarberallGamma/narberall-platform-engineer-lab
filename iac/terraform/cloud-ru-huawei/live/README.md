# Pattern: Terragrunt live (sample env)

DRY layout with per-unit state. Sample `env-dev` units:

- vpc → subnet → route
- security-group → compute

```text
terragrunt-live/
  root.hcl
  _env/
  env-dev/
    vpc/ subnet/ route/
    security-group/ compute/
```

Experience: [`../../../cloud/cloud-ru-huawei.md`](../../../cloud/cloud-ru-huawei.md). Parent: [`../README.md`](../README.md).

