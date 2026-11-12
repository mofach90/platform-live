#!/usr/bin/env bash
# Bring the demo back to its start state — through the pipeline, like every other change.
#
# Usage: scripts/demo_reset.sh [start|empty]      (or: make demo-reset)
#   start (default)  main gets demo/start.yaml (group "web", 2 VMs); the demo branches are rebuilt
#   empty            main gets demo/empty.yaml (no VMs) — to stop paying between rehearsals
#
# What it does:
#   1. PR that sets workloads/shop/dev/workload.yaml on main → waits for the checks → merges
#      → waits for the apply workflow. Skipped if main is already in that state.
#   2. (start only) force-pushes the demo branches, built from the new main and the files in demo/:
#        demo/add-worker  happy path, the presenter opens this PR live
#        demo/invalid     draft PR: unregistered project, bad size, bad count, file in the wrong folder
#        demo/rename      draft PR: web → frontend, the plan shows destroy + create
#
# It only changes the workload file, so only VMs (and their service accounts) are created or
# deleted — never projects, networks or bootstrap. It needs no cloud credentials: the write
# identity stays in CI. It works in a temporary git worktree; your checkout is not touched.
set -euo pipefail

MODE="${1:-start}"
WORKLOAD=workloads/shop/dev/workload.yaml
case "$MODE" in
  start | empty) ;;
  *) echo "usage: $0 [start|empty]" >&2; exit 2 ;;
esac

ROOT="$(git rev-parse --show-toplevel)"
START=$SECONDS
for tool in gh yq; do
  command -v "$tool" >/dev/null || { echo "demo-reset: $tool is not installed" >&2; exit 1; }
done

step() { printf '\n==> %s\n' "$*"; }

# Wait for the run of a workflow on one commit, then follow it. Fails if the run fails.
watch_run() { # <workflow file> <commit sha>
  local id=""
  for _ in $(seq 1 30); do
    id="$(gh run list --workflow "$1" --commit "$2" --limit 1 --json databaseId --jq '.[0].databaseId // empty')"
    [ -n "$id" ] && break
    sleep 4
  done
  [ -n "$id" ] || { echo "demo-reset: no $1 run appeared for commit $2" >&2; exit 1; }
  gh run watch "$id" --exit-status --interval 5 >/dev/null || {
    echo "demo-reset: $1 failed: gh run view $id --log-failed" >&2; exit 1; }
  echo "$1 succeeded (run $id)"
}

step "Fetching origin and preparing a temporary worktree"
git -C "$ROOT" fetch --quiet --prune origin
WORK="$(mktemp -d)"
trap 'git -C "$ROOT" worktree remove --force "$WORK" 2>/dev/null || true' EXIT
git -C "$ROOT" worktree add --quiet --detach "$WORK" origin/main

# --- 1. main → wanted state, through a pull request -------------------------------------------
if git -C "$ROOT" show "origin/main:$WORKLOAD" | cmp -s - "$ROOT/demo/$MODE.yaml"; then
  step "main already matches demo/$MODE.yaml — no reset PR needed"
else
  branch="demo/reset-$(date +%Y%m%d-%H%M%S)"
  step "Reset PR: main → demo/$MODE.yaml (branch $branch)"
  git -C "$WORK" checkout --quiet -b "$branch"
  cp "$ROOT/demo/$MODE.yaml" "$WORK/$WORKLOAD"
  git -C "$WORK" commit --quiet -am "chore(demo): reset shop workload to $MODE state"
  git -C "$WORK" push --quiet -u origin "$branch"
  pr="$(gh pr create --head "$branch" --base main \
        --title "chore(demo): reset shop workload to $MODE state" \
        --body "Created by \`scripts/demo_reset.sh $MODE\`.")"
  echo "$pr"
  watch_run pr.yml "$(git -C "$WORK" rev-parse HEAD)"
  gh pr merge "$pr" --squash --delete-branch >/dev/null
  step "Merged — waiting for the apply workflow"
  watch_run apply.yml "$(gh pr view "$pr" --json mergeCommit --jq .mergeCommit.oid)"
  git -C "$ROOT" fetch --quiet --prune origin
fi

# --- 2. demo branches, rebuilt from the new main ------------------------------------------------
demo_branch() { # <branch> <demo file> <commit message>
  git -C "$WORK" checkout --quiet -B "$1" origin/main
  cp "$ROOT/demo/$2" "$WORK/$WORKLOAD"
  if [ "$1" = demo/invalid ]; then # the "file in the wrong folder" mistake
    cp "$ROOT/demo/start.yaml" "$WORK/workloads/shop/workload.yaml"
    git -C "$WORK" add workloads/shop/workload.yaml
  fi
  git -C "$WORK" commit --quiet -am "$3"
  git -C "$WORK" push --quiet --force origin "$1"
  echo "pushed $1"
}

draft_pr() { # <branch> <title> <body>
  if [ -n "$(gh pr list --head "$1" --state open --json number --jq '.[0].number // empty')" ]; then
    echo "PR for $1 is already open (updated by the push)"
  else
    gh pr create --draft --head "$1" --base main --title "$2" --body "$3"
  fi
}

if [ "$MODE" = start ]; then
  step "Rebuilding the demo branches"
  demo_branch demo/add-worker add-worker.yaml "feat(shop): add worker group"
  demo_branch demo/invalid invalid.yaml "feat(shop): move web to payments project"
  demo_branch demo/rename rename.yaml "refactor(shop): rename web to frontend"
  draft_pr demo/invalid "[demo — do not merge] invalid workload" \
    "Shows the friendly errors: unregistered project, bad size, bad count, file in the wrong folder."
  draft_pr demo/rename "[demo — do not merge] rename web to frontend" \
    "Shows the rename trap: the group name is the identity, so the plan is destroy + create."
fi

# --- 3. What is running now (read-only; skipped without gcloud) ---------------------------------
project_id="$(yq '.projects.shop-dev.projectId' "$ROOT/platform/dev.yaml")"
if command -v gcloud >/dev/null; then
  step "VMs in $project_id"
  gcloud compute instances list --project "$project_id" \
    --format='table(name,zone.basename(),status,networkInterfaces[0].accessConfigs[0].natIP:label=EXTERNAL_IP)' || true
fi

step "Done in $(((SECONDS - START) / 60)) min $(((SECONDS - START) % 60)) s"
if [ "$MODE" = start ]; then
  echo "On stage, open the happy-path PR with:"
  echo "  gh pr create --head demo/add-worker --base main --fill"
fi
