SHELL  := /bin/bash
TF     := terraform
TFVARS := $(CURDIR)/terraform.tfvars

# ENV defaults to prod. Pass ENV=dev to target the additional environment.
ENV ?= prod

# Remote state bucket (managed outside Terraform via `make bootstrap`)
STATE_BUCKET := summit-workshop-tfstate-975800360817
AWS_REGION   := us-east-1
AWS_PROFILE  := summit-workshop

.PHONY: help init fmt validate check-env workspace plan apply destroy outputs smoke bootstrap

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
	@echo "  bootstrap   - one-time: create+configure the S3 state bucket"
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

bootstrap:
	@if aws s3api head-bucket --bucket $(STATE_BUCKET) --profile $(AWS_PROFILE) --region $(AWS_REGION) 2>/dev/null; then \
	  echo "Bucket $(STATE_BUCKET) exists; re-asserting configuration"; \
	else \
	  echo "Creating bucket $(STATE_BUCKET)"; \
	  aws s3api create-bucket --bucket $(STATE_BUCKET) --region $(AWS_REGION) --profile $(AWS_PROFILE); \
	fi
	aws s3api put-bucket-versioning --bucket $(STATE_BUCKET) --versioning-configuration Status=Enabled --profile $(AWS_PROFILE) --region $(AWS_REGION)
	aws s3api put-bucket-encryption --bucket $(STATE_BUCKET) --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}' --profile $(AWS_PROFILE) --region $(AWS_REGION)
	aws s3api put-public-access-block --bucket $(STATE_BUCKET) --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true --profile $(AWS_PROFILE) --region $(AWS_REGION)
	aws s3api put-bucket-tagging --bucket $(STATE_BUCKET) --tagging 'TagSet=[{Key=owner,Value=itay.katz},{Key=extend,Value=true},{Key=project,Value=agent-workshop}]' --profile $(AWS_PROFILE) --region $(AWS_REGION)
	@echo "Bootstrap complete: $(STATE_BUCKET)"
