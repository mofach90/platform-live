# STATUS

**Last updated:** 2026-11-11, ~21:30, Claude Code — `make check` passes (fmt, validate, tflint, trivy, gitleaks)
**Talk:** Sat 14 Nov 2026, 10:00–10:45, DevFest Berlin, Room 3
**Code freeze:** Thu 12 Nov, 12:00

## Done
- Scope, responsibilities, architecture, schedule, demo script → `docs/PLAN.md`, ADR 0001
- Agent setup: workspace `devfest/`, AGENTS.md files, CLAUDE.md imports, `end-session` skill
- Placeholders filled in all docs; org/folder/billing IDs live in gitignored `.env` (ADR 0002) — commit 65c5b23
- Step 0 complete: day-1 checks (region `europe-west10` confirmed, no blocking org policy),
  landing-zone simulation: `teams` folder, project `shop-dev-7d94` with `planner`/`deployer`,
  external-IP policy on the project; impersonation of `planner@` works
- Scaffold: Makefile, `.tool-versions`, `.tflint.hcl`, `.pre-commit-config.yaml`, `.gitleaksignore`,
  CODEOWNERS, `.envrc`, `.env.example`, empty dirs — commit 65c5b23
- Step 1 complete: `platform/dev.yaml` (registry) + `bootstrap/` (WIF pool + provider, ci-plan, ci-apply,
  state bucket, grants per registered project). Human applied (11 added) and migrated the state:
  `gs://platform-project-dev-514319-tfstate/bootstrap/default.tfstate`. WIF hardening applied: ci-apply is
  bound to `apply.yml@refs/heads/main` (ADR 0002 #7). `terraform plan` in `bootstrap/`: no changes — commit bd692bd.
- Local credentials fixed: Terraform ignores `CLOUDSDK_CONFIG`; `.envrc` + Makefile now also set
  `GOOGLE_APPLICATION_CREDENTIALS` (ADR 0002 #1, journal).

## In progress
- nothing

## Next
1. Human: commit the rest of step 1 (`platform/dev.yaml`, ADR 0002, Makefile, AGENTS.md, PLAN.md, STATUS.md).
2. Step 2: `schema/environment.schema.json` + `layers/10-baseline` (APIs, VPC, subnet with Private
   Google Access, router + NAT, IAP firewall, OS Login); wire `make plan`. Human applies once via `deployer@`.
3. Step 3: `modules/vm-group` + `layers/20-workload`.

## Blocked / open questions
- **Human:** protect `main` on GitHub (PR + review, "Require review from Code Owners") — the
  `refs/heads/main` condition on ci-apply is worthless without it.
- **Decide (PLAN §3, before step 2):** impersonate `planner@`/`deployer@` through the provider
  argument `impersonate_service_account`, not `GOOGLE_IMPERSONATE_SERVICE_ACCOUNT` — the GCS backend
  reads that variable too and the team SAs have no access to the state bucket.
- **Known problem for step 4:** the GCS backend writes an empty state on first init of a new state;
  `ci-plan` is read-only on the bucket, so the first PR plan for a new project fails. Needs a design choice.
- **After the talk:** the local gcloud login uses a super-admin account; switch to a normal admin user.
- **Optional cleanup:** `default` VPC with open SSH/RDP firewall rules exists in the platform project.
- **Scope:** freeze is Thu 12:00. Must-have: steps 2–6 + 13. Slides-only if late: 7, 8–10, 12.
- Local shell: Homebrew also has Terraform 1.6.1; `terraform version` must print 1.17.1 (asdf shim first in PATH).
