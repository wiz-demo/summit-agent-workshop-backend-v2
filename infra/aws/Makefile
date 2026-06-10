SHELL  := /bin/bash
TF     := terraform
TFVARS := $(CURDIR)/terraform.tfvars

# ENV defaults to prod. Pass ENV=dev to target the additional environment.
ENV ?= prod

.PHONY: help init fmt validate check-env workspace plan apply destroy outputs smoke

help:
	@echo "Targets (ENV defaults to prod; pass ENV=dev for the additional environment):"
	@echo "  init        - terraform init"
	@echo "  fmt         - terraform fmt"
	@echo "  validate    - terraform validate"
	@echo "  plan        - terraform plan      (e.g. make plan          | make plan ENV=dev)"
	@echo "  apply       - terraform apply     (e.g. make apply         | make apply ENV=dev)"
	@echo "  destroy     - terraform destroy   (e.g. make destroy       | make destroy ENV=dev)"
	@echo "  outputs     - refresh state and print outputs"
	@echo "  smoke       - hit the deployed endpoint with benign + exploit payloads"
	@echo ""
	@echo "Requires: aws configure --profile summit-workshop"

init:
	$(TF) init -input=false

fmt:
	$(TF) fmt

validate:
	$(TF) validate

check-env:
	@if [ "$(ENV)" != "prod" ] && [ "$(ENV)" != "dev" ]; then \
	  echo "ERROR: ENV must be prod or dev (got '$(ENV)')"; exit 1; fi

workspace: check-env
	@$(TF) workspace select $(ENV) 2>/dev/null || $(TF) workspace new $(ENV)

plan: workspace
	$(TF) plan -var-file=$(TFVARS) -var="environment=$(ENV)"

apply: workspace
	$(TF) apply -var-file=$(TFVARS) -var="environment=$(ENV)"

destroy: workspace
	$(TF) destroy -var-file=$(TFVARS) -var="environment=$(ENV)"

outputs: workspace
	@$(TF) refresh -var-file=$(TFVARS) -var="environment=$(ENV)" > /dev/null
	@$(TF) output

smoke: workspace
	@$(TF) refresh -var-file=$(TFVARS) -var="environment=$(ENV)" > /dev/null
	@eval "$$($(TF) output -raw smoke_test_commands)"
