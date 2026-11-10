# STATUS

**Last updated:** 2026-11-07 (planning done in claude.ai; no code, no cloud resources yet)
**Talk:** Sat 14 Nov 2026, 10:00–10:45, DevFest Berlin, Room 3
**Code freeze:** Thu 12 Nov, 12:00

## Done
- Scope, responsibilities, architecture, schedule, demo script → `docs/PLAN.md`, ADR 0001
- Agent setup: workspace `devfest/`, AGENTS.md files, CLAUDE.md imports, `end-session` skill

## In progress
- nothing

## Next
1. Fill placeholders in AGENTS.md / PLAN.md / landing-zone-sim.md.
2. Step 0: day-1 checks (PLAN §6), then landing-zone simulation for `shop-dev` (human runs).
3. Scaffold: Makefile, .tool-versions, .pre-commit-config.yaml, CODEOWNERS, empty dirs.
4. Step 1: `bootstrap/` Terraform (local state → migrate). Human applies.

## Blocked / open questions
- Waiting for placeholder values from the human.
