# Live demos

Run from `platform-live/`, after `make demo-reset` has prepared the branches and draft PRs.

| Script | Slide | What it does | Changes anything? |
|---|---|---|---|
| `demo/1-add-worker.sh` | Live demo 1 | opens the PR from `demo/add-worker`, waits for checks, shows the plan, merges, follows the apply, lists the VMs, SSH through IAP | yes: merge + apply |
| `demo/2-invalid.sh` | Live demo 2 | shows the broken file, the red checks, and runs the validator locally on that branch | no |
| `demo/3-rename.sh` | Live demo 3 | shows the one-word diff and the plan "7 to add, 7 to destroy" | no |
| `demo/4-layer-update.sh` | Live demo 4 | shows the layer release, the Renovate PR and its four plans, merges, follows the apply, lists the labels | yes: merge + apply |

Every step prints the command first and waits: **Enter** runs it, **s** skips it, **q** stops the script.

- `DRY_RUN=1 demo/1-add-worker.sh` shows every command without running it (rehearsal).
- `AUTO=1` does not wait for keys.

The `*.yaml` files here are the workload states used by `scripts/demo_reset.sh`.
After the talk: `make demo-reset MODE=empty`.
