# ADR 0001 — Initial architecture (2026-11-07)

Status: accepted. Split a row into its own ADR when it changes.

| # | Decision | Why | Alternative considered |
|---|----------|-----|------------------------|
| 1 | Landing zone creates team projects + `deployer`/`planner` SAs ( manually); platform only registers and configures them | Mirrors real responsibility split; keeps project-creation rights out of CI | Platform creates projects (project factory in CI): needs folder-level projectCreator + billing.user for CI |
| 2 | Registry `platform/dev.yaml`; workloads reference a project **key**, not a raw ID | Registry = gate; teams cannot target unregistered/foreign projects | Raw projectId in workload.yaml |
| 3 | Three levels: `bootstrap/` (central, manual) → `layers/10-baseline` → `layers/20-workload` | Different owners and change rates; central manages CI's own rights so it stays manual (no self-lockout) | One root module |
| 4 | Baseline and workload run **per project** (GitHub Actions matrix), state per project | Provider identity can't vary inside for_each; per-tenant blast radius | Single state with for_each (impossible with per-project impersonation) |
| 5 | GitHub Actions + WIF, no SA keys; provider condition pins the repo | Keyless, short-lived, auditable | SA JSON key in secrets (rejected) |
| 6 | Read/write split: ci-plan→planner (any PR, `-lock=false`, state read-only); ci-apply→deployer (main only) | A PR must never be able to change infrastructure or state | One SA for everything |
| 7 | One VPC per team project, created by baseline | Self-contained demo | Shared VPC from the LZ (enterprise standard; slide only) |
| 8 | Two repos: platform-live + platform-modules (tagged) | Shows versioning + update-by-PR | Monorepo folders |
| 9 | semantic-release: tag + GitHub Release only, no commit back | Works with protected main without a bypass user | Commit CHANGELOG back |
| 10 | Renovate via hosted GitHub App | Nothing to operate | Self-hosted Renovate; Dependabot |
| 11 | Agent-agnostic: AGENTS.md source of truth, CLAUDE.md imports it, skills in `.agents/skills` linked to `.claude/skills`, Makefile, STATUS.md handoff; workspace = `devfest/` | Switch Claude Code ↔ Codex without losing context | Tool-specific config |