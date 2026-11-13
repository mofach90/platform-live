# AGENTS.md — platform-live

Instructions for any coding agent (Claude Code, Codex, …) and for humans.
Read this file, then `docs/STATUS.md`, `docs/PLAN.md` and `docs/decisions/` first.

## What this repo is
A small self-service VM platform on Google Cloud, built as the live demo for the
DevFest Berlin 2026 talk "From Pull Request to Running App: Building a Small
Platform on Google Cloud" (Sat 14 Nov 2026, 10:00, 45 min, English, public repo).

Responsibilities (see ADR 0001):
- **Landing zone** (simulated by hand, `docs/landing-zone-sim.md`): creates team
  projects, links billing, creates `deployer` + `planner` service accounts in them.
- **Platform team** (this repo): registers projects in `platform/dev.yaml`,
  configures them (baseline layer), owns the VM building blocks and the pipeline.
- **App teams**: write `workloads/<team>/<env>/workload.yaml`, open a PR.

## Layout (target)
```
bootstrap/                 central, MANUAL apply by a human: WIF, ci-plan/ci-apply SAs,
                           state bucket, impersonation grants per registered project
platform/dev.yaml          registry: environment settings + registered team projects
layers/10-baseline/        per project: APIs, VPC/subnet/NAT/IAP firewall, OS Login,
                           snapshot policy          (runs once per project, matrix)
layers/20-workload/        per project: VM groups from workload.yaml (runs once per project)
(modules)                  live in the platform-modules repo, pinned here by tag (`?ref=vX.Y.Z`)
workloads/<team>/<env>/workload.yaml   the only files app teams touch (CODEOWNERS)
schema/                    workload.schema.json, environment.schema.json
scripts/                   validate_workloads.py (friendly errors), changed_projects.py (matrix)
.github/workflows/         pr.yml (validate, scan, plan matrix, PR comment), apply.yml (main)
docs/                      PLAN, STATUS, journal, decisions/, landing-zone-sim.md
```

## Placeholders and local values
Team projects (created via `docs/landing-zone-sim.md`): shop-dev = `shop-dev-7d94` (second team project optional).
Org, folder and billing IDs never go into this public repo: commands use `$ORG_ID`,
`$NONPROD_FOLDER_ID`, `$TEAMS_FOLDER_ID`, `$BILLING_ACCOUNT_ID` from the gitignored
`.env` (template: `.env.example`). `.envrc` (direnv) loads `.env` and sets
`CLOUDSDK_CONFIG=$HOME/.config/gcloud-devfest` and
`GOOGLE_APPLICATION_CREDENTIALS=$CLOUDSDK_CONFIG/application_default_credentials.json`, so the
demo never touches other gcloud configs or ADC. Both are needed: gcloud reads the first,
Terraform only the second. Agents: direnv does not run in your shell — export both
yourself before any `gcloud`/`terraform` command (the Makefile does it for make targets).

## Hard rules
1. NEVER run `terraform apply/destroy/import/state rm`, or any `gcloud`/`gsutil`
   command that creates, changes or deletes cloud resources or IAM. You may run
   fmt, validate, init and plan. Write commands for the human; the human runs
   bootstrap, landing-zone steps and first applies; CI runs apply afterwards.
2. NEVER create or commit service-account keys, tokens or secrets.
   Locally: human ADC + impersonation. In CI: WIF only.
3. Identity split everywhere: PR pipelines use ci-plan → `planner@<team project>`
   (read-only) and `terraform plan -lock=false`; only `main` uses ci-apply →
   `deployer@<team project>`.
4. Keep `for_each` keys stable and name-based. Renaming a key = destroy + create.
   Never use `count` with list indexes for real resources.
5. Every error shown to an app team names: file, field, bad value, allowed
   values, docs link. Never only a raw stack trace.
6. Pin everything: `.tool-versions`, `required_providers`, modules by tag,
   GitHub Actions by full commit SHA.
7. This is a generic, public demo.
8. Walking skeleton: after each change the pipeline must still be green.

## Platform defaults the VM module enforces (teams cannot override)
No external IP · access only via IAP TCP forwarding (35.235.240.0/20) ·
OS Login on, project SSH keys blocked · Shielded VM (secure boot, vTPM,
integrity monitoring) · one service account per VM group, minimal roles ·
labels: team, env, group, managed-by=platform · names built by the platform ·
`size` → machine type (small/medium/large) · images from an allow-list ·
disks attached to the project's snapshot policy.

## Commands (same as CI)
```
make fmt                                  terraform fmt -recursive
make validate                             schemas + registry check + terraform validate
make lint                                 tflint
make scan                                 trivy config . + gitleaks
make plan LAYER=20-workload PROJECT=shop-dev   init + plan -lock=false for one project
make check                                fmt-check + validate + lint + scan (run before finishing)
```

## Working style
- For every non-trivial change explain briefly WHY (pattern name + one alternative).
- Ask before big design decisions; record them as ADRs in `docs/decisions/`.
- Record real failures in `docs/journal.md` (symptom → checks → cause → fix → lesson).
- End every session with the `end-session` skill (updates `docs/STATUS.md`).
