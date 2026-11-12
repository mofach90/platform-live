# Same commands locally and in CI — see AGENTS.md "Commands".
# Written for GNU make 3.81 (macOS default): no .SHELLFLAGS, so loops use `set -e`.
SHELL := /bin/bash
.DEFAULT_GOAL := help

# Locally: the demo's own gcloud dir (accounts, configs, ADC), same as .envrc.
# Terraform (Go) ignores CLOUDSDK_CONFIG and reads ~/.config/gcloud unless
# GOOGLE_APPLICATION_CREDENTIALS points at the demo's ADC file.
# In CI, google-github-actions/auth provides the credentials instead.
ifndef CI
export CLOUDSDK_CONFIG ?= $(HOME)/.config/gcloud-devfest
export GOOGLE_APPLICATION_CREDENTIALS ?= $(CLOUDSDK_CONFIG)/application_default_credentials.json
endif

# Every directory that contains Terraform code.
TF_DIRS := $(sort $(dir $(shell find bootstrap layers modules -name '*.tf' -not -path '*/.terraform/*' 2>/dev/null)))

LAYER ?=
PROJECT ?=
# planner (read-only) for plans; `make apply` always uses deployer.
IDENTITY ?= planner

.PHONY: help fmt fmt-check validate lint scan plan apply check

help: ## list targets
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "} {printf "  %-10s %s\n", $$1, $$2}'

fmt: ## terraform fmt -recursive
	terraform fmt -recursive

fmt-check: ## fail if a .tf file is not formatted
	terraform fmt -recursive -check -diff

validate: ## schemas + registry check + terraform validate
	@if [ -f scripts/validate_workloads.py ]; then python3 scripts/validate_workloads.py; \
	else echo "validate: scripts/validate_workloads.py not written yet (PLAN step 2/6), skipped"; fi
	@set -e; for d in $(TF_DIRS); do \
	  echo "terraform validate $$d"; \
	  terraform -chdir=$$d init -backend=false -input=false >/dev/null; \
	  terraform -chdir=$$d validate; \
	done

lint: ## tflint (rules in .tflint.hcl)
	tflint --init --config "$(CURDIR)/.tflint.hcl"
	tflint --recursive --config "$(CURDIR)/.tflint.hcl"

scan: ## trivy config + gitleaks
	trivy config --exit-code 1 --severity HIGH,CRITICAL --skip-dirs '**/.terraform' --quiet .
	gitleaks git --no-banner --redact .

plan: ## init + plan -lock=false for one project: make plan LAYER=20-workload PROJECT=shop-dev
	@test -n "$(LAYER)" && test -n "$(PROJECT)" || { echo "usage: make plan LAYER=<10-baseline|20-workload> PROJECT=<key in platform/dev.yaml>"; exit 2; }
	@test -d layers/$(LAYER) || { echo "plan: layers/$(LAYER) does not exist (have: $$(ls layers | tr '\n' ' '))"; exit 2; }
	@set -e; layer="$(LAYER)"; \
	terraform -chdir=layers/$(LAYER) init -reconfigure -input=false -backend-config="prefix=$${layer#*-}/$(PROJECT)" >/dev/null; \
	terraform -chdir=layers/$(LAYER) plan -lock=false -input=false -var project_key=$(PROJECT) -var identity=$(IDENTITY)

apply: ## init + apply as deployer; CI runs this on main, a human only for a first apply (asks for "yes")
	@test -n "$(LAYER)" && test -n "$(PROJECT)" || { echo "usage: make apply LAYER=<10-baseline|20-workload> PROJECT=<key in platform/dev.yaml>"; exit 2; }
	@test -d layers/$(LAYER) || { echo "apply: layers/$(LAYER) does not exist (have: $$(ls layers | tr '\n' ' '))"; exit 2; }
	@set -e; layer="$(LAYER)"; \
	terraform -chdir=layers/$(LAYER) init -reconfigure -input=false -backend-config="prefix=$${layer#*-}/$(PROJECT)" >/dev/null; \
	terraform -chdir=layers/$(LAYER) apply $(if $(CI),-input=false -auto-approve) -var project_key=$(PROJECT) -var identity=deployer

check: fmt-check validate lint scan ## run before finishing (same as CI)
