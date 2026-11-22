#!/usr/bin/env bash
# Stop paying for the demo platform between work sessions, and bring it back later.
#
# Usage: scripts/platform_pause.sh <status|pause|teardown|resume>      (or: make pause STEP=...)
#   status    read-only: lists everything in the platform that costs money
#   pause     removes all VMs (and their disks) through the pipeline: one PR that empties every
#             workload file, merged, applied. Networks stay. Costs left: the NAT address of each
#             team project, about 0.25 euro a day in total, plus snapshots until they expire (7 days).
#   teardown  pause + removes the baseline of every team project (NAT, router, network, firewall,
#             snapshot schedule) and the snapshots, then disables the apply workflow so no merge
#             rebuilds anything by accident. Costs left: the state bucket, well under 1 euro a month.
#   resume    enables the apply workflow and rebuilds every baseline; then add VMs as usual
#             (make demo-reset, or revert the pause PR).
#
# Never touched: projects, the planner/deployer accounts, bootstrap (WIF, CI identities, state bucket).
# Projects are kept on purpose: a deleted project ID can never be reused.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
export CLOUDSDK_CONFIG="${CLOUDSDK_CONFIG:-$HOME/.config/gcloud-devfest}"
export GOOGLE_APPLICATION_CREDENTIALS="${GOOGLE_APPLICATION_CREDENTIALS:-$CLOUDSDK_CONFIG/application_default_credentials.json}"

REGISTRY=platform/dev.yaml
ENV_NAME="$(yq '.environment' "$REGISTRY")"
PLATFORM_PROJECT="$(yq '.platformProject' "$REGISTRY")"
KEYS="$(yq '.projects | keys | .[]' "$REGISTRY")"
step() { printf '\n==> %s\n' "$*"; }
pid() { P="$1" yq '.projects[strenv(P)].projectId' "$REGISTRY"; }
team() { P="$1" yq '.projects[strenv(P)].team' "$REGISTRY"; }

status() {
  local p id
  for p in $KEYS; do
    id="$(pid "$p")"
    step "$p ($id)"
    echo "-- VMs";            gcloud compute instances list --project "$id" --format='table(name,zone.basename(),status,machineType.basename())' 2>&1 | sed 's/^/   /'
    echo "-- disks";          gcloud compute disks list --project "$id" --format='table(name,sizeGb,type.basename())' 2>&1 | sed 's/^/   /'
    echo "-- snapshots";      gcloud compute snapshots list --project "$id" --format='table(name,diskSizeGb,creationTimestamp.date())' 2>&1 | sed 's/^/   /'
    echo "-- NAT routers";    gcloud compute routers list --project "$id" --format='table(name,region.basename())' 2>&1 | sed 's/^/   /'
    echo "-- reserved IPs";   gcloud compute addresses list --project "$id" --format='table(name,address,status)' 2>&1 | sed 's/^/   /'
  done
  step "platform project $PLATFORM_PROJECT"
  echo "-- VMs";              gcloud compute instances list --project "$PLATFORM_PROJECT" --format='table(name,zone.basename(),status)' 2>&1 | sed 's/^/   /'
  echo "-- buckets (pennies)"; gcloud storage du -s -r "gs://$(yq '.stateBucket' "$REGISTRY")" 2>&1 | sed 's/^/   /'
  step "apply workflow"
  gh api "repos/{owner}/{repo}/actions/workflows/apply.yml" --jq '"   " + .state'
}

# Wait for the run of a workflow on one commit, then follow it. Fails if the run fails.
watch_run() { # <workflow file> <commit sha>
  local id="" i
  for i in $(seq 1 40); do
    id="$(gh run list --workflow "$1" --commit "$2" --limit 1 --json databaseId --jq '.[0].databaseId // empty')"
    [ -n "$id" ] && break; sleep 4
  done
  [ -n "$id" ] || { echo "no $1 run appeared for commit $2" >&2; exit 1; }
  echo "waiting for $1: $(gh run view "$id" --json url --jq .url)"
  gh run watch "$id" --exit-status --interval 10 >/dev/null || { echo "$1 failed: gh run view $id --log-failed" >&2; exit 1; }
  echo "$1 succeeded"
}

pause() {
  step "Empty every workload file on main, through a pull request"
  git fetch --quiet --prune origin
  local work branch p t f changed=0
  work="$(mktemp -d)"; trap 'git worktree remove --force "$work" 2>/dev/null || true' RETURN
  git worktree add --quiet --detach "$work" origin/main
  for p in $KEYS; do
    t="$(team "$p")"; f="workloads/$t/$ENV_NAME/workload.yaml"
    [ -f "$work/$f" ] || continue
    if [ "$(yq '.spec.vmGroups | length' "$work/$f")" != 0 ]; then
      printf 'apiVersion: platform.demo/v1\nkind: Workload\nmetadata: { team: %s, env: %s }\nspec:\n  project: %s\n  vmGroups: []            # paused (scripts/platform_pause.sh); revert this commit to get the VMs back\n' \
        "$t" "$ENV_NAME" "$p" > "$work/$f"
      changed=1; echo "   $f → no VMs"
    fi
  done
  if [ "$changed" = 0 ]; then echo "   every workload file is already empty"; return 0; fi
  branch="chore/pause-$(date +%Y%m%d-%H%M%S)"
  git -C "$work" commit --quiet -am "chore: pause the platform, remove all VMs"
  git -C "$work" push --quiet origin "HEAD:refs/heads/$branch"
  local pr; pr="$(gh pr create --head "$branch" --base main --title "chore: pause the platform, remove all VMs" \
    --body "Created by \`scripts/platform_pause.sh pause\`. Revert this PR to get the VMs back.")"
  echo "   $pr"
  watch_run pr.yml "$(git -C "$work" rev-parse HEAD)"
  echo "   the plan comment shows what will be destroyed: $pr"
  read -r -p "   merge and remove the VMs now? [y/N] " ok
  [ "$ok" = y ] || { echo "   not merged; the PR stays open"; exit 0; }
  gh pr merge "$pr" --squash >/dev/null
  git push --quiet origin --delete "$branch" || true
  step "Merged; the apply workflow removes the VMs"
  watch_run apply.yml "$(gh pr view "$pr" --json mergeCommit --jq .mergeCommit.oid)"
}

teardown() {
  pause
  step "Disable the apply workflow, so no merge rebuilds anything while paused"
  gh workflow disable apply.yml
  local p id
  for p in $KEYS; do
    step "$p: destroy workload, then baseline (Terraform asks for yes each time)"
    scripts/tf_layer.sh destroy workload "$p"
    scripts/tf_layer.sh destroy baseline "$p"
    id="$(pid "$p")"
    step "$p: snapshots left behind"
    local snaps; snaps="$(gcloud compute snapshots list --project "$id" --format='value(name)')"
    if [ -n "$snaps" ]; then
      echo "$snaps" | sed 's/^/   /'
      read -r -p "   delete these snapshots? [y/N] " ok
      [ "$ok" = y ] && gcloud compute snapshots delete $snaps --project "$id" --quiet
    else echo "   none"; fi
  done
  step "Done. What is left:"; status
}

resume() {
  step "Enable the apply workflow and rebuild every baseline from main"
  gh workflow enable apply.yml
  gh workflow run apply.yml --ref main
  sleep 8
  watch_run apply.yml "$(git ls-remote origin refs/heads/main | cut -f1)"
  cat <<'TXT'

The baselines are back (networks, NAT, IAP firewall, snapshot schedule). VMs are not:
  shop demo state:  make demo-reset
  everything:       revert the "chore: pause the platform" pull request (gh pr list --state merged)
TXT
}

case "${1:-}" in
  status) status ;;
  pause) pause; step "What is left:"; status ;;
  teardown) teardown ;;
  resume) resume ;;
  *) sed -n '2,16p' "$0"; exit 2 ;;
esac
