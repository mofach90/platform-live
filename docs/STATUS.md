# STATUS

**Last updated:** 2026-11-12, morning, Claude Code — `make check` not re-run after step 5 (no Terraform code changed)
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
- Steps 2 + 3: baseline applied for shop-dev; vm-group module + workload layer — commits 9b9755f, 0ee93d7.
- Step 4 complete: `pr.yml` ran green on test PR #1 (closed, not merged): one plan comment — commit 9009459.

## In progress
- Step 5 written, **not committed, never run**: `.github/workflows/apply.yml` (push to main or manual run →
  registry keys → baseline matrix → workload matrix, as ci-apply → `deployer@`, concurrency per project+layer)
  and a `make apply` target (auto-approve only when `CI` is set).
- Local branch is still `test/plan-pipeline` (count: 3, PR closed); the step 5 files are uncommitted on top of it.

## Next
1. Human: `git switch main`, new branch, commit step 5, PR → check the plan comment (20-workload: 5 to add) →
   merge → `apply` workflow creates `shop-web-01/02`; test IAP SSH. Fix what the first run shows.
2. Step 6: `scripts/validate_workloads.py` (schema + registry + path, all errors at once, plain text).
3. Step 13: reset script + backup video (must-have before the freeze).

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
