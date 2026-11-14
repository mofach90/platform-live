# STATUS

**Last updated:** 2026-11-13, evening, Claude Code — `make check` passes (fmt, validate, tflint, trivy, gitleaks)
**Talk:** Sat 14 Nov 2026, 10:00–10:45, DevFest Berlin, Room 3
**Code freeze:** now (Fri 13 Nov evening). All 13 plan steps are built; only docs and the demo routine remain.

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

- Step 7 complete: daily snapshot schedule + boot-disk attachment, applied via CI — PR #17.

- Step 8 complete: `vm-group` lives in platform-modules, pinned by tag — PR #18.
- Step 9 complete: semantic-release in platform-modules; `feat:` commit produced `v1.1.0` + GitHub Release.

- Layers split complete (ADR 0003): repos `platform-layer-baseline` / `platform-layer-workload` released `v1.0.0`
  by semantic-release; platform-live pins them in `platform/dev.yaml`; PR #19 planned "No changes" for both
  layers, apply after merge green; demo branches rebuilt. `vm-group` lives inside the workload layer repo.

- Step 10 complete: `renovate.json` + Renovate GitHub App (hosted). First bot PR: #23, workload layer `v1.1.0`
  (label `size` on VMs). Finding: the hosted app caches tag lists (~1 h), so a release is not picked up at once.
- Step 12 complete: team `blog`, project `blog-dev-b617` onboarded (landing-zone steps, registry, bootstrap
  grants, first plans by the human) — PR #22; apply built the baseline and `blog-web-01`.

- Full timed rehearsal done by the human on 13 Nov; `make demo-reset` ran at ~19:20, start state is live
  (shop-web-01/02, blog-web-01).

## In progress
- Nothing is being built. PR #23 (Renovate, workload layer v1.1.0) stays open on purpose: it is demo scene 5.
  All its checks are green. Its comment still shows an old line for the blog baseline ("10 to add"); a full
  re-run of its `pr` workflow refreshes it.
- Uncommitted: `docs/STATUS.md`, `docs/PLAN.md` (demo script §7 rewritten for the final setup).

## Next
1. Human: commit the docs through a PR (docs only: no plan, no apply).
2. Human: `gh run rerun <latest pr run of PR #23>` so its plan comment is current.
3. Saturday ~09:00: `make demo-reset`, check VMs in both projects, the two draft PRs and PR #23; open tabs.
   After the talk: `make demo-reset MODE=empty` (shop only) and empty `workloads/blog/dev/workload.yaml` by PR.

## Blocked / open questions
- Decided: the first plan of a new state is run by a human at onboarding (`bootstrap/README.md`), because
  the GCS backend writes an empty state then and `ci-plan` stays read-only on the bucket.
- **After the talk:** the local gcloud login uses a super-admin account; switch to a normal admin user.
- **Optional cleanup:** `default` VPC with open SSH/RDP firewall rules exists in the platform project.
- **Decided:** no backup video. Fallback on stage: merged PRs #19 and #22 with their plan comments.
- **After the talk:** onboarding in two PRs (project first, workload second) so no plan is red; self-hosted
  Renovate if instant bot PRs are wanted (needs a GitHub App key); archive `platform-modules`;
  delete stale branches `feat/apply-pipeline`, `fix/demo-reset-branches`.
- Local shell: Homebrew also has Terraform 1.6.1; `terraform version` must print 1.17.1 (asdf shim first in PATH).
