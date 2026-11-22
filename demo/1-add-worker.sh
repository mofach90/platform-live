#!/usr/bin/env bash
# Live demo 1: the shop team adds a worker group.
# pull request -> checks -> plan comment -> merge -> apply -> VMs without external IP -> SSH through IAP
. "$(dirname "$0")/lib.sh"
BRANCH=demo/add-worker
git fetch --quiet origin

title "Demo 1: the shop team adds a worker group"

say "The whole change: four lines in one file."
run "git --no-pager diff origin/main...origin/$BRANCH -- workloads/"

say "The team opens a pull request."
PR="$(pr_number "$BRANCH")"
if [ -z "$PR" ]; then
  run "gh pr create --head $BRANCH --base main --title 'feat(shop): add worker group' --body 'The shop team needs three workers.'"
  PR="$(pr_number "$BRANCH")"
else
  echo "  pull request #$PR is already open"
fi
[ -n "$PR" ] || PR="<number>"
run "gh pr view $PR --web"

say "Checks: validate, scan, which projects changed, one plan."
[ -n "${DRY_RUN:-}" ] || wait_for_checks "$PR"
run "gh pr checks $PR --watch --interval 5"

say "The plan, as the reviewer sees it in the comment."
run "gh pr view $PR --comments   # only the summary lines" "plan_summary $PR"

say "Merge = approval. Then the apply workflow runs on main."
merge_and_follow "$PR"

say "What exists now: five VMs, no external IP."
run "gcloud compute instances list --project $SHOP_PROJECT --format='table(name,zone.basename(),status,networkInterfaces[0].networkIP:label=INTERNAL_IP,networkInterfaces[0].accessConfigs[0].natIP:label=EXTERNAL_IP)'"

say "No public address, and still inside: through IAP."
run "gcloud compute ssh shop-worker-01 --project $SHOP_PROJECT --zone ${REGION}-a --tunnel-through-iap --command 'hostname; hostname -I'"
