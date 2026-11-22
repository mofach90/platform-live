#!/usr/bin/env bash
# Live demo 2: four mistakes in one pull request (draft PR of branch demo/invalid, prepared by make demo-reset).
. "$(dirname "$0")/lib.sh"
BRANCH=demo/invalid
git fetch --quiet origin
PR="$(pr_number "$BRANCH")"; [ -n "$PR" ] || PR="$BRANCH"

title "Demo 2: four mistakes in one pull request"

say "The broken request: wrong project, size huge, count 50."
run "git --no-pager show origin/$BRANCH:workloads/shop/dev/workload.yaml"

say "And a file in the wrong folder."
run "git --no-pager diff --stat origin/main...origin/$BRANCH -- workloads/"

say "The pull request: validate is red, no plan was made, merge is blocked."
run "gh pr checks $PR"
run "gh pr view $PR --web"

say "The same check on my laptop: four mistakes, four messages, one run."
TMP="$(mktemp -d)"
run "python3 scripts/validate_workloads.py   # on the files of $BRANCH" \
  "git archive origin/$BRANCH platform schema workloads | tar -x -C '$TMP' && python3 scripts/validate_workloads.py '$TMP'"
rm -rf "$TMP"
