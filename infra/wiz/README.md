# Wiz Connectors (Terraform)

Provisions Wiz connectors via the `wiz-v2` Terraform provider:

- **AWS** connector targeting account `800618367342`, plus the IAM role Wiz
  assumes to scan it (two-stage apply: IAM role first, then connector).
- **GitHub** connector (GitHub App auth against github.com). Self-contained —
  no IAM dependency; provisioned with the root module.
- **Two Wiz tenants** — the stack now supports provisioning connectors for TWO
  separate Wiz tenants scanning the same AWS account, configured via the `*_2`
  variables in `terraform.tfvars`.

Adapted from the `terraform-test` reference repo.

## Prerequisites

- Terraform `>= 1.10.0`
- AWS CLI v2 with SSO configured for profile `dev-product-cto-play`
- A Wiz service account (Wiz Console → Settings → Service Accounts) with at
  least `create:connectors` and `read:tenant` scopes
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

After apply, check the Wiz UI under Settings → Connectors. Both
`TF-AWS-Connector-CodeChallange` and `TF-GitHub-Connector-CodeChallange`
should appear and start their first scan within a few minutes. If tenant 2 is
configured, its connectors (suffixed `-Tenant2`) will appear in tenant 2's
Wiz UI.

## Tear down

```bash
make destroy   # destroys connector first, then IAM role
```

## Two Wiz tenants

The stack supports provisioning connectors for TWO separate Wiz tenants that
scan the same AWS account (`800618367342`). This allows separate Wiz
organizations to independently assess the same infrastructure.

- **Tenant 1** (primary) is configured via the base variables: `wiz_client_id`,
  `wiz_client_secret`, `wiz_env`, `wiz_role_name`, `iam_policy_suffix`,
  `wiz_remote_arn`, `connector_name`, `github_connector_name`, and
  `project_name_dev`.

- **Tenant 2** is configured entirely via the `*_2` variables in
  `terraform.tfvars`: `wiz_client_id_2`, `wiz_client_secret_2`, `wiz_env_2`,
  `wiz_role_name_2`, `iam_policy_suffix_2`, `wiz_remote_arn_2`,
  `connector_name_2`, `github_connector_name_2`, and `project_name_dev_2`.

The `wiz-iam` sub-project provisions ONE IAM role per tenant. Both roles live
in the same AWS account, so they must have distinct names (`wiz_role_name` vs
`wiz_role_name_2`) and distinct policy suffixes (`iam_policy_suffix` vs
`iam_policy_suffix_2`). Each role trusts its respective Wiz data-center
delegator ARN (`wiz_remote_arn` / `wiz_remote_arn_2`).

The tenant-2 GitHub connector reuses tenant 1's GitHub App (same
`github_app_id` and PEM file). Both connectors authenticate to github.com with
the same credentials.

Running `make apply` provisions both tenants in a single run: IAM roles for
both tenants first (via the `wiz-iam` sub-project), then connectors and
projects for both tenants.

Tenant 2's UI objects are suffixed `-Tenant2` (e.g.
`TF-AWS-Connector-CodeChallange-Tenant2`) to distinguish them from tenant 1.

## Layout

```
infra/wiz/
├── versions.tf, providers.tf, variables.tf      Root module
├── connector_aws.tf                             wiz-v2_generic_connector resource
├── connector_github.tf                          wiz-v2_generic_connector (github)
├── terraform.tfvars.example                     Reference values (no secrets)
├── terraform.tfvars                             Local-only, gitignored
├── Makefile                                     init / plan / apply / destroy
└── wiz-iam/
    ├── versions.tf, providers.tf, variables.tf  Sub-module
    ├── main.tf                                  Wiz's published IAM module
    └── outputs.tf                               Exposes role_arn
```

The root module reads the IAM role ARN from `wiz-iam/terraform.tfstate` via
`terraform_remote_state`. This is a deliberate workaround for a `wiz-v2`
provider bug where `customerRoleARN` referencing an unknown-after-apply value
triggers an `auth_params_hash__` inconsistency error.

## Things this won't do

- Does NOT scan account `432513806796` (the `cto-experts` profile's account)
- Does NOT modify the ECS-on-EC2 deployment from `infra/aws/`
- Does NOT configure Bedrock, DocumentDB, or any other supporting service
