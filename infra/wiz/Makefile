SHELL   := /bin/bash
TF      := terraform
TFVARS  := $(CURDIR)/terraform.tfvars
AWS_DIR := ../aws

# Which infra/aws environment the Wiz project groups. The project filters on
# tag environment=$(ENV) in account 975800360817, so that AWS stack must be
# deployed first (see check-aws-deployed). Override with `make apply ENV=prod`.
ENV     ?= prod

.PHONY: help init plan apply destroy require-env check-aws-deployed \
        init-iam plan-iam apply-iam destroy-iam \
        init-root plan-root apply-root destroy-root

help:
	@echo "Two-stage workflow (IAM role first, then connector that consumes it):"
	@echo "  init        - terraform init for both sub-projects"
	@echo "  plan        - terraform plan for both sub-projects"
	@echo "  apply       - terraform apply IAM first, then root (connector)"
	@echo "  destroy     - terraform destroy root (connector) first, then IAM"
	@echo
	@echo "Individual targets exist for each stage (init-iam, plan-iam, apply-iam, etc.)."
	@echo
	@echo "REQUIREMENTS before any apply:"
	@echo "  1. Copy terraform.tfvars.example to terraform.tfvars"
	@echo "  2. Fill in wiz_client_id and wiz_client_secret from Wiz Console"
	@echo "     (Settings > Service Accounts)"
	@echo "  3. aws sso login --profile summit-workshop"
	@echo "  4. terraform login tf.app.wiz.io  (only first time, if private registry asks)"
	@echo
	@echo "CROSS-STACK DEPENDENCY:"
	@echo "  apply gates on the infra/aws stack for ENV (default dev) being"
	@echo "  deployed, since the Wiz project groups its environment=ENV resources."
	@echo "  Deploy AWS first:  make -C $(AWS_DIR) apply ENV=$(ENV)"

# Cross-stack dependency guard ------------------------------------------------
# The Wiz project (project_dev.tf) only has resources to group once the
# infra/aws stack for ENV is deployed. These targets fail fast (no auto-apply)
# if that stack has no resources yet.

require-env:
	@if [ "$(ENV)" != "prod" ] && [ "$(ENV)" != "dev" ]; then \
	  echo "ERROR: ENV must be prod or dev (got '$(ENV)')"; exit 1; fi

check-aws-deployed: require-env
	@if [ -z "$$(TF_WORKSPACE=$(ENV) $(TF) -chdir=$(AWS_DIR) state list 2>/dev/null)" ]; then \
	  echo "ERROR: infra/aws '$(ENV)' stack is not deployed (no resources in workspace '$(ENV)')."; \
	  echo "Deploy it first:  make -C $(AWS_DIR) apply ENV=$(ENV)"; \
	  exit 1; fi

init: init-iam init-root

plan: plan-iam plan-root

apply: apply-iam apply-root

# Reverse order: connector depends on the IAM role, so destroy it first.
destroy: destroy-root destroy-iam

# ---------- wiz-iam sub-project ----------

init-iam:
	cd wiz-iam && $(TF) init

plan-iam:
	cd wiz-iam && $(TF) plan -var-file=$(TFVARS) -compact-warnings

apply-iam:
	cd wiz-iam && $(TF) apply -var-file=$(TFVARS) -auto-approve -compact-warnings

destroy-iam:
	cd wiz-iam && $(TF) destroy -var-file=$(TFVARS) -auto-approve -compact-warnings

# ---------- root (connector) ----------

init-root:
	$(TF) init

# The shared tfvars carries wiz-iam-only keys too, so -compact-warnings
# condenses the harmless "undeclared variable" notices from the root module.
plan-root:
	$(TF) plan -var-file=$(TFVARS) -compact-warnings

apply-root:
	$(TF) apply -var-file=$(TFVARS) -auto-approve -compact-warnings

destroy-root:
	$(TF) destroy -var-file=$(TFVARS) -auto-approve -compact-warnings
