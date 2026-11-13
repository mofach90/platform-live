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

# Terraform code in this repo: only bootstrap. Layers live in their own repos (platform/dev.yaml).
TF_DIRS := bootstrap/

LAYER ?=
PROJECT ?=
# Layers: baseline, workload (see platform/dev.yaml → layers). planner (read-only) for plans;
# `make apply` always uses deployer.
IDENTITY ?= planner

.PHONY: help fmt fmt-check validate lint scan plan apply demo-reset check

help: ## list targets
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "} {printf "  %-10s %s\n", $$1, $$2}'

fmt: ## terraform fmt -recursive
	terraform fmt -recursive

fmt-check: ## fail if a .tf file is not formatted
	terraform fmt -recursive -check -diff

validate: ## schemas + registry check + terraform validate
	@python3 scripts/validate_workloads.py
	@set -e; for d in $(TF_DIRS); do \
	  echo "terraform validate $$d"; \
	  terraform -chdir=$$d init -backend=false -input=false >/dev/null; \
	  terraform -chdir=$$d validate; \
	done

lint: ## tflint (rules in .tflint.hcl)
	tflint --init --config "$(CURDIR)/.tflint.hcl"
	tflint --recursive --config "$(CURDIR)/.tflint.hcl"

scan: ## trivy config + gitleaks
	trivy config --exit-code 1 --severity HIGH,CRITICAL --skip-dirs '**/.terraform' --skip-dirs .layers --quiet .
	gitleaks git --no-banner --redact .

plan: ## read-only plan of one layer for one project: make plan LAYER=workload PROJECT=shop-dev
	@scripts/tf_layer.sh plan "$(LAYER)" "$(PROJECT)" $(IDENTITY)

apply: ## apply as deployer; CI runs this on main, a human only for a first apply (asks for "yes")
	@scripts/tf_layer.sh apply "$(LAYER)" "$(PROJECT)"

demo-reset: ## demo back to its start state through the pipeline (MODE=empty removes all VMs)
	@scripts/demo_reset.sh $(or $(MODE),start)

check: fmt-check validate lint scan ## run before finishing (same as CI)
