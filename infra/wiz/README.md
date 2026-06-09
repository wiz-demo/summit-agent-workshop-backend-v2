# Wiz Connectors (Terraform)

Provisions Wiz connectors via the `wiz-v2` Terraform provider:

- **AWS** connector targeting account `800618367342`, plus the IAM role Wiz
  assumes to scan it (two-stage apply: IAM role first, then connector).
- **GitHub** connector (GitHub App auth against github.com). Self-contained —
  no IAM dependency; provisioned with the root module.
- **Three Wiz tenants** — the stack provisions connectors for THREE separate
  Wiz tenants scanning the same AWS account, configured via `_t1` and `_t2`
  suffixed variables in `terraform.tfvars`.

Adapted from the `terraform-test` reference repo.

## Prerequisites

- Terraform `>= 1.10.0`
- AWS CLI v2 with SSO configured for profile `dev-product-cto-play`
- A Wiz service account (Wiz Console → Settings → Service Accounts) with at
  least `create:connectors` and `read:tenant` scopes — one per tenant
- Access to the Wiz private Terraform registry at `tf.app.wiz.io`
  (`terraform login tf.app.wiz.io` if `terraform init` prompts)

## First-time setup

```bash
cd infra/wiz

# Fill in your Wiz secrets locally (file is gitignored — secrets won't be committed)
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars

# Save the GitHub App private key (gitignored). Set github_app_id in
# terraform.tfvars; keep the default path or override github_app_private_key_path.
cp /path/to/your-downloaded-key.pem github-app.pem

# AWS SSO
aws sso login --profile dev-product-cto-play
```

## Apply

```bash
make init    # init both sub-projects
make plan    # plan both
make apply   # IAM first, then connector
```

After apply, check the Wiz UI under Settings → Connectors. The original
tenant's connectors (`TF-AWS-Connector-AgentWorkshop`,
`TF-GitHub-Connector-AgentWorkshop`) should appear and start their first scan
within a few minutes. Tenant 1 and Tenant 2 connectors (suffixed `-Tenant1`,
`-Tenant2`) will appear in their respective Wiz UIs.

## Tear down

```bash
make destroy   # destroys connector first, then IAM role
```

## Three Wiz tenants

The stack supports provisioning connectors for THREE separate Wiz tenants that
scan the same AWS account (`800618367342`). This allows separate Wiz
organizations to independently assess the same infrastructure.

- **Original tenant** (primary) is configured via the base variables:
  `wiz_client_id`, `wiz_client_secret`, `wiz_env`, `wiz_role_name`,
  `iam_policy_suffix`, `wiz_remote_arn`, `connector_name`,
  `github_connector_name`, and `project_name_dev`.

- **Tenant 1** is configured via the `*_t1` variables: `wiz_client_id_t1`,
  `wiz_client_secret_t1`, `wiz_env_t1`, `wiz_role_name_t1`,
  `iam_policy_suffix_t1`, `wiz_remote_arn_t1`, `connector_name_t1`,
  `github_connector_name_t1`, and `project_name_dev_t1`.

- **Tenant 2** is configured via the `*_t2` variables: `wiz_client_id_t2`,
  `wiz_client_secret_t2`, `wiz_env_t2`, `wiz_role_name_t2`,
  `iam_policy_suffix_t2`, `wiz_remote_arn_t2`, `connector_name_t2`,
  `github_connector_name_t2`, and `project_name_dev_t2`.

The `wiz-iam` sub-project provisions ONE IAM role per tenant. All three roles
live in the same AWS account, so they must have distinct names
(`wiz_role_name`, `wiz_role_name_t1`, `wiz_role_name_t2`) and distinct policy
suffixes (`iam_policy_suffix`, `iam_policy_suffix_t1`, `iam_policy_suffix_t2`).
Each role trusts its respective Wiz data-center delegator ARN (`wiz_remote_arn`,
`wiz_remote_arn_t1`, `wiz_remote_arn_t2`).

The tenant 1 and tenant 2 GitHub connectors reuse the original tenant's GitHub
App (same `github_app_id` and PEM file). All connectors authenticate to
github.com with the same credentials.

Running `make apply` provisions all three tenants in a single run: IAM roles
for all tenants first (via the `wiz-iam` sub-project), then connectors and
projects for all tenants.

Tenant 1 UI objects are suffixed `-Tenant1` and tenant 2 UI objects are
suffixed `-Tenant2` to distinguish them from the original tenant.

## Layout

```
infra/wiz/
├── versions.tf, providers.tf, variables.tf      Root module
├── connector_aws.tf                             wiz-v2_generic_connector resource
├── connector_github.tf                          wiz-v2_generic_connector (github)
├── project_dev.tf                               wiz-v2_project (dev environment)
├── terraform.tfvars.example                     Reference values (no secrets)
├── terraform.tfvars                             Local-only, gitignored
├── Makefile                                     init / plan / apply / destroy
└── wiz-iam/
    ├── versions.tf, providers.tf, variables.tf  Sub-module
    ├── main.tf                                  Wiz's published IAM module
    └── outputs.tf                               Exposes role_arn, role_arn_t1, role_arn_t2
```

The root module reads the IAM role ARN from `wiz-iam/terraform.tfstate` via
`terraform_remote_state`. This is a deliberate workaround for a `wiz-v2`
provider bug where `customerRoleARN` referencing an unknown-after-apply value
triggers an `auth_params_hash__` inconsistency error.

## Things this won't do

- Does NOT scan account `432513806796` (the `cto-experts` profile's account)
- Does NOT modify the ECS-on-EC2 deployment from `infra/aws/`
- Does NOT configure Bedrock, DocumentDB, or any other supporting service
