#!/usr/bin/env bash
# Live demo 3: the rename trap (draft PR of branch demo/rename, prepared by make demo-reset).
. "$(dirname "$0")/lib.sh"
BRANCH=demo/rename
git fetch --quiet origin
PR="$(pr_number "$BRANCH")"; [ -n "$PR" ] || PR="$BRANCH"

title "Demo 3: a change that looks harmless"

say "One word changes: web becomes frontend."
run "git --no-pager diff origin/main...origin/$BRANCH -- workloads/"

say "The checks are green. The YAML is valid."
run "gh pr checks $PR"

say "But the plan tells the truth."
run "gh pr view $PR --comments   # only the summary lines" "plan_summary $PR"
run "gh pr view $PR --web"

say "Not merged. The plan stopped it."
