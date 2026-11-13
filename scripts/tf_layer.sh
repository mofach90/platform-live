#!/usr/bin/env bash
# Run one layer for one project: fetch the layer code at the version pinned in the
# registry, then terraform init + plan/apply with one state per project.
#
# Usage: scripts/tf_layer.sh <plan|apply> <layer> <project key> [planner|deployer]
#        (normally through: make plan / make apply)
#
# The layer code lives in its own repo. platform/dev.yaml says which version this
# environment runs:
#   layers:
#     baseline: { source: mofach90/platform-layer-baseline, version: v1.0.0 }
#
# LAYER_DIR=<path> uses a local checkout instead, to try unreleased layer code (plan only).
set -euo pipefail

REGISTRY=platform/dev.yaml
DOCS=https://github.com/mofach90/platform-live/blob/main/docs/decisions/0003-layers-in-their-own-repos.md

action="${1:-}"; layer="${2:-}"; project="${3:-}"; identity="${4:-planner}"
case "$action" in
  plan | apply) ;;
  *) echo "usage: $0 <plan|apply> <layer> <project key> [planner|deployer]" >&2; exit 2 ;;
esac
cd "$(git rev-parse --show-toplevel)"

source="$(LAYER="$layer" yq '.layers[strenv(LAYER)].source // ""' "$REGISTRY")"
version="$(LAYER="$layer" yq '.layers[strenv(LAYER)].version // ""' "$REGISTRY")"
if [ -z "$layer" ] || [ -z "$source" ] || [ -z "$version" ]; then
  {
    echo "File: $REGISTRY, field: layers"
    echo "Bad value: \"$layer\" is not a layer of this environment."
    echo "Allowed values: $(yq '.layers | keys | join(", ")' "$REGISTRY")"
    echo "Docs: $DOCS"
  } >&2
  exit 2
fi

if [ -n "${LAYER_DIR:-}" ]; then
  [ "$action" = plan ] || { echo "tf_layer: LAYER_DIR is for plans only; apply always uses the pinned version." >&2; exit 2; }
  dir="$LAYER_DIR"
  # Keep Terraform's working files here, so the layer checkout stays untouched.
  export TF_DATA_DIR="$PWD/.layers/_local/$layer"
  echo "Layer $layer: LOCAL CHECKOUT $dir (not the pinned $version)"
else
  dir=".layers/$layer/$version"
  if [ ! -d "$dir" ]; then
    git -c advice.detachedHead=false clone --quiet --depth 1 --branch "$version" \
      "https://github.com/$source.git" "$dir" || {
      {
        echo "File: $REGISTRY, field: layers.$layer.version"
        echo "Bad value: \"$version\" could not be fetched from https://github.com/$source"
        echo "Allowed values: a released tag, see https://github.com/$source/tags"
        echo "Docs: $DOCS"
      } >&2
      exit 1
    }
  fi
  echo "Layer $layer: $source $version"
fi

# Inputs every layer may read; a layer ignores the ones it does not declare.
export TF_VAR_registry_file="$PWD/$REGISTRY"
export TF_VAR_workloads_dir="$PWD/workloads"
export TF_VAR_project_key="$project"

terraform -chdir="$dir" init -reconfigure -input=false \
  -backend-config="bucket=$(yq '.stateBucket' "$REGISTRY")" \
  -backend-config="prefix=$layer/$project" >/dev/null

if [ "$action" = plan ]; then
  TF_VAR_identity="$identity" terraform -chdir="$dir" plan -lock=false -input=false
else
  # Auto-approve only in CI; a human is asked for "yes".
  TF_VAR_identity=deployer terraform -chdir="$dir" apply ${CI:+-input=false -auto-approve}
fi
