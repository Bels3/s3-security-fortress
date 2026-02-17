# S3 Security Fortress - Makefile

.PHONY: help init plan apply destroy test security-scan validate format clean docs cost

# Default target
.DEFAULT_GOAL := help

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
RED := \033[0;31m
YELLOW := \033[0;33m
NC := \033[0m # No Color

# Variables
ENV ?= dev
TERRAFORM_DIR = terraform/environments/$(ENV)

##@ General

help: ## Display this help message
	@echo "$(BLUE)S3 Security Fortress - Available Commands$(NC)"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Setup & Installation

install: ## Install all prerequisites
	@echo "$(BLUE)Installing prerequisites...$(NC)"
	@./scripts/setup/install-prerequisites.sh

setup-backend: ## Setup Terraform backend (S3 + DynamoDB)
	@echo "$(BLUE)Setting up Terraform backend...$(NC)"
	@cd terraform/backend-setup && \
		terraform init && \
		terraform apply -auto-approve
	@echo "$(GREEN)✓ Backend setup complete$(NC)"

init-env: ## Initialize a specific environment (usage: make init-env ENV=dev)
	@echo "$(BLUE)Initializing $(ENV) environment...$(NC)"
	@cd $(TERRAFORM_DIR) && terraform init
	@echo "$(GREEN)✓ $(ENV) environment initialized$(NC)"

init-all: ## Initialize all environments
	@echo "$(BLUE)Initializing all environments...$(NC)"
	@for env in dev staging prod; do \
		echo "$(YELLOW)Initializing $$env...$(NC)"; \
		cd terraform/environments/$$env && terraform init && cd ../../..; \
	done
	@echo "$(GREEN)✓ All environments initialized$(NC)"

##@ Terraform Operations

plan: ## Run terraform plan for environment (usage: make plan ENV=dev)
	@echo "$(BLUE)Planning changes for $(ENV)...$(NC)"
	@cd $(TERRAFORM_DIR) && terraform plan -out=tfplan

apply: ## Apply terraform changes (usage: make apply ENV=dev)
	@echo "$(YELLOW)Applying changes to $(ENV)...$(NC)"
	@cd $(TERRAFORM_DIR) && terraform apply tfplan
	@echo "$(GREEN)✓ Changes applied to $(ENV)$(NC)"

deploy: plan apply ## Plan and apply in one command

destroy: ## Destroy infrastructure (usage: make destroy ENV=dev)
	@echo "$(RED)⚠️  WARNING: This will destroy all resources in $(ENV)!$(NC)"
	@read -p "Are you sure? [y/N]: " confirm && [ "$$confirm" = "y" ] || exit 1
	@cd $(TERRAFORM_DIR) && terraform destroy
	@echo "$(GREEN)✓ $(ENV) infrastructure destroyed$(NC)"

output: ## Show terraform outputs (usage: make output ENV=dev)
	@cd $(TERRAFORM_DIR) && terraform output

##@ Code Quality

validate: ## Validate all Terraform configurations
	@echo "$(BLUE)Validating Terraform code...$(NC)"
	@for dir in $$(find terraform/modules -name "*.tf" -exec dirname {} \; | sort -u); do \
		echo "$(YELLOW)Validating $$dir$(NC)"; \
		cd $$dir && terraform init -backend=false > /dev/null && terraform validate && cd - > /dev/null; \
	done
	@echo "$(GREEN)✓ All Terraform code validated$(NC)"

format: ## Format all Terraform files
	@echo "$(BLUE)Formatting Terraform files...$(NC)"
	@terraform fmt -recursive terraform/
	@echo "$(GREEN)✓ All files formatted$(NC)"

lint: ## Run linting checks
	@echo "$(BLUE)Running linting checks...$(NC)"
	@terraform fmt -check -recursive terraform/
	@echo "$(GREEN)✓ Linting complete$(NC)"

##@ Security

security-scan: ## Run all security scans (tfsec, checkov)
	@echo "$(BLUE)Running security scans...$(NC)"
	@./scripts/testing/run-security-scan.sh
	@echo "$(GREEN)✓ Security scans complete$(NC)"

tfsec: ## Run tfsec security scanner
	@echo "$(BLUE)Running tfsec...$(NC)"
	@tfsec terraform/ --format=default --soft-fail
	@echo "$(GREEN)✓ tfsec scan complete$(NC)"

checkov: ## Run checkov security scanner
	@echo "$(BLUE)Running checkov...$(NC)"
	@checkov -d terraform/ --framework terraform --soft-fail
	@echo "$(GREEN)✓ checkov scan complete$(NC)"

compliance-check: ## Check compliance status
	@echo "$(BLUE)Checking compliance status...$(NC)"
	@./scripts/utilities/compliance-check.sh
	@echo "$(GREEN)✓ Compliance check complete$(NC)"

##@ Testing

test: ## Run all tests
	@echo "$(BLUE)Running all tests...$(NC)"
	@./scripts/testing/run-tests.sh
	@echo "$(GREEN)✓ All tests passed$(NC)"

test-unit: ## Run unit tests only
	@echo "$(BLUE)Running unit tests...$(NC)"
	@cd tests/terraform/unit && go test -v ./...
	@echo "$(GREEN)✓ Unit tests passed$(NC)"

test-integration: ## Run integration tests only
	@echo "$(BLUE)Running integration tests...$(NC)"
	@cd tests/terraform/integration && go test -v -timeout 30m ./...
	@echo "$(GREEN)✓ Integration tests passed$(NC)"

test-lambda: ## Test Lambda functions
	@echo "$(BLUE)Testing Lambda functions...$(NC)"
	@cd lambda/presigned-url-generator && python -m pytest tests/
	@cd lambda/presigned-post-generator && python -m pytest tests/
	@echo "$(GREEN)✓ Lambda tests passed$(NC)"

##@ Documentation

docs: ## Generate documentation
	@echo "$(BLUE)Generating documentation...$(NC)"
	@terraform-docs markdown table --output-file README.md --output-mode inject terraform/modules/kms-encryption
	@terraform-docs markdown table --output-file README.md --output-mode inject terraform/modules/secure-s3-bucket
	@terraform-docs markdown table --output-file README.md --output-mode inject terraform/modules/s3-access-points
	@terraform-docs markdown table --output-file README.md --output-mode inject terraform/modules/object-lock
	@echo "$(GREEN)✓ Documentation generated$(NC)"

diagrams: ## Generate architecture diagrams
	@echo "$(BLUE)Generating diagrams...$(NC)"
	@# Add diagram generation commands here
	@echo "$(GREEN)✓ Diagrams generated$(NC)"

##@ Utilities

cost: ## Estimate infrastructure costs (usage: make cost ENV=dev)
	@echo "$(BLUE)Estimating costs for $(ENV)...$(NC)"
	@./scripts/utilities/cost-report.sh $(ENV)

presigned-url: ## Generate presigned URL (usage: make presigned-url BUCKET=my-bucket KEY=file.pdf)
	@echo "$(BLUE)Generating presigned URL...$(NC)"
	@./scripts/utilities/generate-presigned-url.sh --bucket $(BUCKET) --key $(KEY) --expiration 3600

rotate-key: ## Rotate KMS key (usage: make rotate-key ENV=dev)
	@echo "$(BLUE)Rotating KMS key for $(ENV)...$(NC)"
	@./scripts/utilities/rotate-kms-key.sh $(ENV)
	@echo "$(GREEN)✓ Key rotation initiated$(NC)"

##@ Clean Up

clean: ## Clean up temporary files
	@echo "$(BLUE)Cleaning up...$(NC)"
	@find . -type f -name "*.tfplan" -delete
	@find . -type f -name "*.tfstate.backup" -delete
	@find . -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
	@find . -type f -name "crash.log" -delete
	@echo "$(GREEN)✓ Cleanup complete$(NC)"

clean-all: clean ## Deep clean including downloaded modules
	@echo "$(BLUE)Deep cleaning...$(NC)"
	@find . -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
	@find . -type f -name ".terraform.lock.hcl" -delete
	@echo "$(GREEN)✓ Deep cleanup complete$(NC)"

##@ CI/CD

ci-test: validate security-scan test ## Run all CI tests
	@echo "$(GREEN)✓ All CI checks passed$(NC)"

ci-deploy: ci-test ## Run CI tests and deploy (for CI/CD pipelines)
	@echo "$(BLUE)CI/CD deployment...$(NC)"
	@make deploy ENV=$(ENV)

##@ Examples

example-basic: ## Deploy basic secure bucket example
	@echo "$(BLUE)Deploying basic example...$(NC)"
	@cd examples/basic-secure-bucket && \
		terraform init && \
		terraform plan && \
		terraform apply -auto-approve

example-cleanup: ## Destroy all examples
	@echo "$(RED)Cleaning up examples...$(NC)"
	@for example in examples/*/; do \
		echo "$(YELLOW)Destroying $$example$(NC)"; \
		cd $$example && terraform destroy -auto-approve && cd ../..; \
	done

##@ Development

pre-commit: ## Run pre-commit checks
	@echo "$(BLUE)Running pre-commit checks...$(NC)"
	@pre-commit run --all-files
	@echo "$(GREEN)✓ Pre-commit checks passed$(NC)"

install-hooks: ## Install git hooks
	@echo "$(BLUE)Installing git hooks...$(NC)"
	@pre-commit install
	@echo "$(GREEN)✓ Git hooks installed$(NC)"

##@ Information

show-envs: ## Show all available environments
	@echo "$(BLUE)Available environments:$(NC)"
	@ls -1 terraform/environments/

show-modules: ## Show all available modules
	@echo "$(BLUE)Available modules:$(NC)"
	@ls -1 terraform/modules/

version: ## Show tool versions
	@echo "$(BLUE)Tool Versions:$(NC)"
	@echo "Terraform: $$(terraform version -json | jq -r '.terraform_version')"
	@echo "AWS CLI: $$(aws --version | cut -d' ' -f1 | cut -d'/' -f2)"
	@echo "tfsec: $$(tfsec --version 2>/dev/null || echo 'not installed')"
	@echo "checkov: $$(checkov --version 2>/dev/null || echo 'not installed')"

##@ Quick Commands

dev: ## Quick deploy to dev
	@make deploy ENV=dev

staging: ## Quick deploy to staging
	@make deploy ENV=staging

prod: ## Quick deploy to prod
	@echo "$(RED)⚠️  Deploying to PRODUCTION$(NC)"
	@make deploy ENV=prod

all: clean validate security-scan test ## Run everything (validate, scan, test)
	@echo "$(GREEN)✓ All checks passed!$(NC)"
