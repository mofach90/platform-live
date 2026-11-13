# AGENTS.md — devfest workspace

This folder is a WORKSPACE, not a git repository. It contains four independent repos:

| Folder | Repo | Purpose |
|--------|------|---------|
| `platform-live/` | `mofach90/platform-live` | what runs: bootstrap, registry, layers, team workloads, CI, **all project docs** |
| `platform-modules/` | `mofach90/platform-modules` | **retired** (ADR 0003 #8): the `vm-group` module now lives in the workload layer repo |
| `platform-layer-baseline/` | `mofach90/platform-layer-baseline` | baseline layer code, pinned by tag in `platform-live/platform/dev.yaml` |
| `platform-layer-workload/` | `mofach90/platform-layer-workload` | workload layer code incl. `modules/vm-group`, pinned the same way |

## Start of every session
1. Read `platform-live/AGENTS.md` (main rules) and `platform-modules/AGENTS.md`.
2. Read `platform-live/docs/STATUS.md`, then `platform-live/docs/PLAN.md`
   and `platform-live/docs/decisions/`.
   STATUS, PLAN, journal and ADRs exist ONLY in platform-live — never copy them here.

## Rules for working across both repos
1. Before editing a file in a repo, that repo's AGENTS.md rules apply.
2. Git: never run git at this level. Use `git -C platform-live …` / `git -C platform-modules …`.
   Run `git -C <repo> status` before every commit. One commit belongs to exactly one repo.
3. Make: run inside the repo, e.g. `make -C platform-live check`.
4. Cross-repo change order (ADR 0003): change the layer (or its module) in its repo → PR → merge with
   a Conventional Commit → semantic-release tags it → bump `layers.<name>.version` in
   `platform-live/platform/dev.yaml` (or merge the Renovate PR).
   Never point platform-live at a branch or an untagged commit.
5. platform-live has no `layers/` or `modules/` folder; leave platform-modules alone (retired).
6. Skills: `.agents/skills` and `.claude/skills` here are links to
   `platform-live/.agents/skills`. Edit skills there.
7. Workspace files (this AGENTS.md, CLAUDE.md, the links) are not versioned.
   A copy of this file lives in `platform-live/docs/workspace/AGENTS.md`; keep them identical.
