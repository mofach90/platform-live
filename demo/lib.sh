#!/usr/bin/env bash
# Helpers for the live-demo scripts in this folder. Sourced by them, not run directly.
#
# Every step shows the command first and then waits for a key:
#   Enter = run it      s = skip it      q = quit the script
# DRY_RUN=1 shows every command but runs none (read-only lookups still happen).
# AUTO=1    does not wait for a key (quick rehearsal).
set -uo pipefail

cd "$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)" || exit 1

# Same gcloud directory as the Makefile and .envrc: the demo's own login.
export CLOUDSDK_CONFIG="${CLOUDSDK_CONFIG:-$HOME/.config/gcloud-devfest}"

REGISTRY=platform/dev.yaml
SHOP_PROJECT="$(yq '.projects.shop-dev.projectId' "$REGISTRY")"
BLOG_PROJECT="$(yq '.projects.blog-dev.projectId' "$REGISTRY")"
REGION="$(yq '.region' "$REGISTRY")"
WORKLOAD_LAYER_REPO="$(yq '.layers.workload.source' "$REGISTRY")"
export SHOP_PROJECT BLOG_PROJECT REGION WORKLOAD_LAYER_REPO

c_cmd=$'\033[1;33m'; c_dim=$'\033[2m'; c_hd=$'\033[1;37m'; c_off=$'\033[0m'

title() { printf '\n%s== %s ==%s\n' "$c_hd" "$*" "$c_off"; }
say() { printf '\n%s# %s%s\n' "$c_dim" "$*" "$c_off"; }

# run "<command shown>" ["<command executed, if different>"]
run() {
  local shown="$1" actual="${2:-$1}" key=""
  printf '%s$ %s%s ' "$c_cmd" "$shown" "$c_off"
  if [ -z "${AUTO:-}" ] && [ -t 0 ]; then IFS= read -r -s -n 1 key || key=""; fi
  printf '\n'
  case "$key" in
    s | S) printf '%s  skipped%s\n' "$c_dim" "$c_off"; return 0 ;;
    q | Q) printf '%s  stopped%s\n' "$c_dim" "$c_off"; exit 0 ;;
  esac
  if [ -n "${DRY_RUN:-}" ]; then printf '%s  (dry run: not executed)%s\n' "$c_dim" "$c_off"; return 0; fi
  eval "$actual" || printf '%s  (exit code %s, the demo goes on)%s\n' "$c_dim" "$?" "$c_off"
}

# Number of the open pull request of a branch (empty if there is none).
pr_number() { gh pr list --head "$1" --state open --json number --jq '.[0].number // empty'; }

# A new pull request has no checks for a few seconds; wait until GitHub lists them.
wait_for_checks() {
  local i
  for i in $(seq 1 30); do
    [ "$(gh pr checks "$1" --json name --jq length 2>/dev/null || echo 0)" -gt 0 ] && return 0
    sleep 2
  done
}

# The summary lines of the plan comment on a pull request, as plain text.
plan_summary() {
  gh pr view "$1" --json comments \
    --jq '[.comments[] | select(.body | startswith("<!-- platform-plan -->"))][-1].body // ""' |
    grep '<summary>' | sed -E 's/<[^>]+>//g; s/^/  /'
}

# Wait until a pull request is merged (in the browser or by the step before) and print the merge commit.
merge_commit() {
  local i state
  for i in $(seq 1 100); do
    state="$(gh pr view "$1" --json state --jq .state)"
    if [ "$state" = MERGED ]; then gh pr view "$1" --json mergeCommit --jq .mergeCommit.oid; return 0; fi
    sleep 3
  done
  return 1
}

# Follow the apply workflow that a merge commit started.
watch_apply() {
  local id="" i
  for i in $(seq 1 30); do
    id="$(gh run list --workflow apply.yml --commit "$1" --limit 1 --json databaseId --jq '.[0].databaseId // empty')"
    [ -n "$id" ] && break
    sleep 3
  done
  [ -n "$id" ] || { echo "no apply run found for commit $1"; return 1; }
  gh run watch "$id" --interval 5
}

# Merge step shared by demo 1 and demo 4: merge, then follow the apply.
merge_and_follow() { # <pr number>
  run "gh pr merge $1 --squash"
  if [ -n "${DRY_RUN:-}" ]; then run "gh run watch <the apply run of the merge commit>"; return 0; fi
  printf '%s  waiting for the merge (here or in the browser)...%s\n' "$c_dim" "$c_off"
  local sha; sha="$(merge_commit "$1")" || { echo "  not merged yet; stopping here"; return 1; }
  run "gh run watch   # the apply run of merge commit ${sha:0:7}" "watch_apply $sha"
}
