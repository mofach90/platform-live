#!/usr/bin/env python3
"""Print the plan matrix for a pull request as JSON: [{"project": ..., "layer": ...}].

Usage: changed_projects.py <base-git-ref>

Rules:
- only workloads/<team>/<env>/ changed  → 20-workload for that team's projects
- platform/, layers/, Makefile, scripts/ or workflows changed → every project, both layers
- anything else (docs, …) → empty matrix, no plan needed

Reads platform/dev.yaml through `yq` (preinstalled on GitHub runners), so no pip packages are needed.
"""
import json
import subprocess
import sys

REGISTRY = "platform/dev.yaml"
LAYERS = ["10-baseline", "20-workload"]
EVERYTHING = ("platform/", "layers/", "scripts/", "Makefile", ".github/workflows/", ".tool-versions")


def run(*cmd):
    return subprocess.run(cmd, check=True, capture_output=True, text=True).stdout


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    registry = json.loads(run("yq", "-o=json", ".", REGISTRY))
    projects = registry["projects"]
    env = registry["environment"]
    changed = run("git", "diff", "--name-only", f"{sys.argv[1]}...HEAD").split()

    if any(path.startswith(EVERYTHING) for path in changed):
        matrix = [{"project": key, "layer": layer} for key in sorted(projects) for layer in LAYERS]
    else:
        # workloads/<team>/<env>/workload.yaml → projects of that team in this environment
        teams = {p.split("/")[1] for p in changed if p.startswith("workloads/") and p.split("/")[2:3] == [env]}
        matrix = [
            {"project": key, "layer": "20-workload"}
            for key in sorted(projects)
            if projects[key]["team"] in teams
        ]
    print(json.dumps(matrix))


if __name__ == "__main__":
    main()
