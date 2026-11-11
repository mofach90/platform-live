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
- Steps 2 + 3 done and committed (9b9755f, 0ee93d7): baseline applied for shop-dev; workload layer plans 5 to add.
- Step 4 written, **not committed, never run**: `.github/workflows/pr.yml` (validate → matrix → plan per
  project as ci-plan → one updated PR comment), `scripts/changed_projects.py` (matrix, needs `yq`),
  onboarding note in `bootstrap/README.md` (human runs the first plan of a new state).
  Actions pinned by SHA. Only a real pull request can prove the workflow works.

## Next
1. Human: commit + push step 4, open a test PR that touches `workloads/shop/dev/workload.yaml`;
   done when the PR shows one readable plan comment (5 to add). Fix what the first run shows.
2. Step 5: `apply.yml` (must keep this file name — WIF binding) → first VMs via CI; test IAP SSH.
3. Step 6: `scripts/validate_workloads.py` (schema + registry + path, all errors at once, plain text).

## Blocked / open questions
- **Human:** protect `main` on GitHub (PR + review, "Require review from Code Owners") — the
  `refs/heads/main` condition on ci-apply is worthless without it.
- Decided: the first plan of a new state is run by a human at onboarding (`bootstrap/README.md`), because
  the GCS backend writes an empty state then and `ci-plan` stays read-only on the bucket.
- `scripts/validate_workloads.py` (schema + registry check) is not written yet; `make validate` skips it.
- **After the talk:** the local gcloud login uses a super-admin account; switch to a normal admin user.
- **Optional cleanup:** `default` VPC with open SSH/RDP firewall rules exists in the platform project.
- **Scope:** freeze is Thu 12:00. Must-have: steps 2–6 + 13. Slides-only if late: 7, 8–10, 12.
- Local shell: Homebrew also has Terraform 1.6.1; `terraform version` must print 1.17.1 (asdf shim first in PATH).
