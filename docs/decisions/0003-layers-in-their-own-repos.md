# ADR 0003 — Layers in their own repos, pinned in the registry (2026-11-13)

Status: accepted. Replaces the `layers/` folder of ADR 0001 #3 (the three levels stay).

| # | Decision | Why | Alternative considered |
|---|----------|-----|------------------------|
| 1 | Each layer is its own repo: `platform-layer-baseline`, `platform-layer-workload`. Each releases tags with semantic-release | A layer change becomes a release; rolling it out is a separate, reviewed decision | One repo for both layers (one tag series, half the setup); layers next to the modules |
| 2 | `platform/<env>.yaml` pins `layers.<name>.source` + `version` (tag `vX.Y.Z`, never a branch) | One file says what an environment runs. Promotion = a PR that changes one version in that environment's file | Thin Terraform wrappers with `?ref=` (Renovate reads them natively, but the pin is not in the registry); Terragrunt (built for this, one more tool) |
| 3 | `scripts/tf_layer.sh` fetches the pinned tag into `.layers/<name>/<version>` and runs Terraform there. Terraform cannot do it itself: a module `source` may not contain a variable | Smallest glue that works locally and in CI through the same `make plan` / `make apply` | `terraform init -from-module` (copies files, awkward to cache) |
| 4 | Layers get their inputs as `TF_VAR_registry_file`, `TF_VAR_workloads_dir`, `TF_VAR_project_key`, `TF_VAR_identity`; bucket and prefix as `-backend-config` | Layer code holds no environment values, so the same tag can serve dev and prod | Hard-coded bucket and relative paths (as before) |
| 5 | A change to `platform/` plans and applies every project, baseline before workload | Merging a version bump rolls the new layer out to the whole environment | Apply only the layer whose version changed |
| 6 | Layer repos have no cloud access; their CI only validates. `LAYER_DIR=<checkout> make plan …` plans unreleased code read-only from platform-live | The WIF provider accepts only `mofach90/platform-live`; one place holds cloud rights | Give each layer repo its own plan identity |
| 7 | State keys are unchanged: `baseline/<project>`, `workload/<project>` | The move must plan as "No changes" | — |
| 8 | The `vm-group` module lives inside `platform-layer-workload` (`modules/vm-group`, local source). `platform-modules` is no longer used | A module change is one layer release and one PR in platform-live; every layer tag is fixed code | Pin the module by tag in the layer (two releases and two bumps per change); point at the module's `main` branch (no bumps, but module merges reach every environment without a release, PR or reviewed plan) |

Known costs: the module cannot be shared by another layer without moving it out again;
a change that needs new layer code and a new registry field takes two PRs in order;
a moved tag would change what runs (tags are trusted, as for modules); `.layers/` is a cache and
can be deleted at any time.
