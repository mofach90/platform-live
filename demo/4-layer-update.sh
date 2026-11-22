#!/usr/bin/env bash
# Live demo 4: the bot's pull request. A new version of the workload layer is rolled out to every project.
. "$(dirname "$0")/lib.sh"
git fetch --quiet origin
PR="$(gh pr list --author app/renovate --state open --json number --jq '.[0].number // empty')"

title "Demo 4: the bot's pull request"

say "The layer repo released a new version. The number comes from the commit message."
run "gh release list -R $WORKLOAD_LAYER_REPO --limit 3"

if [ -z "$PR" ]; then
  say "No open Renovate pull request (the hosted bot caches the version list)."
  say "Fallback: show the last one it opened."
  run "gh pr list --author app/renovate --state all --limit 3"
  exit 0
fi

say "Renovate opened pull request #$PR. It changes one line."
run "gh pr diff $PR"

say "One plan per project and layer: what does the new version do to every team?"
run "gh pr view $PR --comments   # only the summary lines" "plan_summary $PR"
run "gh pr view $PR --web"

say "A human merges. The apply rolls the new layer out to shop and blog."
merge_and_follow "$PR"

say "Every VM now carries the new label."
run "gcloud compute instances list --project $SHOP_PROJECT --format='table(name,labels.group,labels.size)'"
run "gcloud compute instances list --project $BLOG_PROJECT --format='table(name,labels.group,labels.size)'"
