# STATUS

**Last updated:** 2026-11-13, morning, Claude Code — fmt, validate, tflint, trivy, gitleaks pass
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

- Step 5 complete: `apply.yml` + `make apply`; merge of PR #2 created `shop-web-01/02` via CI as ci-apply →
  `deployer@`; IAP SSH works — commits 2003dfa, daf0a28.
- `main` is protected by a ruleset: PR required (0 approvals — solo demo), no force push, no deletion,
  required check `validate`.

- Step 6 complete: validator + workload schema + `workloads/README.md`; invalid PR #4 shows red `validate`
  with clear messages and merge is blocked — commits d97384a, 5ecd2ba.

- Step 13 script complete: `make demo-reset` and `MODE=empty` both ran end to end (about 3 min each);
  demo branches + draft PRs #6 (invalid) and #7 (rename) exist — PRs #5, #9, #12.

- Step 11 complete: job `scan` in `pr.yml` (tflint, trivy, gitleaks, pinned by version + sha256), green — PR #16.

## In progress
- Step 7 written, **not committed, not applied**: snapshot schedule `platform-daily` (daily 03:00 UTC, 7 days,
  expires after disk deletion) in `layers/10-baseline`; `vm-group` attaches each boot disk to it by name
  (separate attachment resource, VMs are not recreated). Local plans as planner: baseline 1 to add,
  workload 2 to add, nothing replaced.
- Backup video not recorded (step 13's second half).

## Next
1. Human: PR with step 7 → merge → apply; done when the disks show the schedule and a second
   plan of both layers says "No changes" (checks that the attachment causes no drift on the VM).
2. Human: `make demo-reset` afterwards (rebuilds the demo branches on the new main), full rehearsal,
   backup video. Plan counts changed: add-worker is now 9 to add (3 VMs, 3 attachments, 1 SA, 2 bindings).
3. Step 8 (modules to `platform-modules`, pin by tag) only if the user wants it before the talk.

## Blocked / open questions
- Decided: the first plan of a new state is run by a human at onboarding (`bootstrap/README.md`), because
  the GCS backend writes an empty state then and `ci-plan` stays read-only on the bucket.
- **After the talk:** the local gcloud login uses a super-admin account; switch to a normal admin user.
- **Optional cleanup:** `default` VPC with open SSH/RDP firewall rules exists in the platform project.
- **Scope:** freeze is Thu 12:00. Must-have: steps 2–6 + 13. Slides-only if late: 7, 8–10, 12.
- Local shell: Homebrew also has Terraform 1.6.1; `terraform version` must print 1.17.1 (asdf shim first in PATH).
