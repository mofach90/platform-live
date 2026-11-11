# Same commands locally and in CI — see AGENTS.md "Commands".
# Written for GNU make 3.81 (macOS default): no .SHELLFLAGS, so loops use `set -e`.
SHELL := /bin/bash
.DEFAULT_GOAL := help

# Locally: the demo's own gcloud dir (accounts, configs, ADC), same as .envrc.
# In CI, google-github-actions/auth provides the credentials instead.
ifndef CI
export CLOUDSDK_CONFIG ?= $(HOME)/.config/gcloud-devfest
endif

# Every directory that contains Terraform code.
TF_DIRS := $(sort $(dir $(shell find bootstrap layers modules -name '*.tf' -not -path '*/.terraform/*' 2>/dev/null)))

LAYER ?=
PROJECT ?=

.PHONY: help fmt fmt-check validate lint scan plan check

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
	@test -d layers/$(LAYER) || { echo "plan: layers/$(LAYER) does not exist yet (PLAN step 2/3)"; exit 2; }
	@echo "plan: wired up together with the first layer (PLAN step 2)"; exit 2

check: fmt-check validate lint scan ## run before finishing (same as CI)
