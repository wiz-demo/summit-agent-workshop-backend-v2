# Wiz Connectors (Terraform)

Provisions Wiz connectors via the `wiz-v2` Terraform provider for two
independent Wiz tenants scanning the same AWS account:

- **AWS** connectors targeting account `975800360817`, plus the IAM roles Wiz
  assumes to scan it (two-stage apply: IAM roles first, then connectors).
- **GitHub** connectors (GitHub App auth against github.com). Self-contained —
  no IAM dependency; provisioned with the root module. Currently disabled for
  both tenants (commented out in `connector_github.tf`).

Adapted from the `terraform-test` reference repo.

## Prerequisites

- Terraform `>= 1.10.0`
- AWS CLI v2 with profile `summit-workshop` configured
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

# AWS credentials (profile must be configured)
aws sts get-caller-identity --profile summit-workshop
```

## Apply

```bash
make init    # init both sub-projects
make plan    # plan both
make apply   # IAM first, then connector
```

After apply, Tenant 1 and Tenant 2 connectors (suffixed `-Tenant1`,
`-Tenant2`) will appear in their respective Wiz UIs and start their first
scan within a few minutes.

## Tear down

```bash
make destroy   # destroys connector first, then IAM role
```

## Two Wiz tenants

The stack provisions connectors for TWO separate Wiz tenants that scan the
same AWS account (`975800360817`). This allows separate Wiz organizations to
independently assess the same infrastructure.

- **Tenant 1** is configured via the `*_t1` variables: `wiz_client_id_t1`,
  `wiz_client_secret_t1`, `wiz_env_t1`, `wiz_role_name_t1`,
  `iam_policy_suffix_t1`, `wiz_remote_arn_t1`, `connector_name_t1`,
  `github_connector_name_t1`, and `project_name_dev_t1`.

- **Tenant 2** is configured via the `*_t2` variables: `wiz_client_id_t2`,
  `wiz_client_secret_t2`, `wiz_env_t2`, `wiz_role_name_t2`,
  `iam_policy_suffix_t2`, `wiz_remote_arn_t2`, `connector_name_t2`,
  `github_connector_name_t2`, and `project_name_dev_t2`.

The `wiz-iam` sub-project provisions ONE IAM role per tenant. Both roles
live in the same AWS account, so they must have distinct names
(`wiz_role_name_t1`, `wiz_role_name_t2`) and distinct policy suffixes
(`iam_policy_suffix_t1`, `iam_policy_suffix_t2`). Each role trusts its
respective Wiz data-center delegator ARN (`wiz_remote_arn_t1`,
`wiz_remote_arn_t2`).

Both GitHub connectors reuse the same GitHub App (`github_app_id` and PEM
file). All connectors authenticate to github.com with the same credentials.

Running `make apply` provisions both tenants in a single run: IAM roles
first (via the `wiz-iam` sub-project), then connectors and projects.

## Layout

```
infra/wiz/
├── versions.tf, providers.tf, variables.tf      Root module
├── connector_aws.tf                             wiz-v2_generic_connector resources
├── connector_github.tf                          wiz-v2_generic_connector (github)
├── project_dev.tf                               wiz-v2_project (dev environment)
├── terraform.tfvars.example                     Reference values (no secrets)
├── terraform.tfvars                             Local-only, gitignored
├── Makefile                                     init / plan / apply / destroy
└── wiz-iam/
    ├── versions.tf, providers.tf, variables.tf  Sub-module
    ├── main.tf                                  Wiz's published IAM module
    └── outputs.tf                               Exposes role_arn_t1, role_arn_t2
```

The root module reads the IAM role ARNs from `wiz-iam/terraform.tfstate` via
`terraform_remote_state`. This is a deliberate workaround for a `wiz-v2`
provider bug where `customerRoleARN` referencing an unknown-after-apply value
triggers an `auth_params_hash__` inconsistency error.

## Things this won't do

- Does NOT scan account `432513806796` (the `cto-experts` profile's account)
- Does NOT modify the ECS-on-EC2 deployment from `infra/aws/`
- Does NOT configure Bedrock, DocumentDB, or any other supporting service
