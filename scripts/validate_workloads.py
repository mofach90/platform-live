#!/usr/bin/env python3
"""Validate platform/dev.yaml and every workloads/<team>/<env>/workload.yaml.

Usage: validate_workloads.py [repo-root]

Three kinds of rules, all errors reported in one run:
- shape:    the JSON schemas in schema/ (types, allowed values, ranges, unknown fields)
- path:     workloads/<team>/<env>/workload.yaml must match metadata.team / metadata.env
- registry: spec.project must be registered in platform/dev.yaml and belong to the team

Every error names file, field, bad value, allowed values and a docs link (AGENTS.md rule 5).
On GitHub Actions each error is also an annotation on the line of the pull request.

YAML is read through `yq` (preinstalled on GitHub runners), so no pip packages are needed.
The schema check supports exactly the keywords used in schema/ and stops on any other.
"""
import json
import os
import re
import subprocess
import sys
from pathlib import Path

REPO_URL = "https://github.com/mofach90/platform-live/blob/main"
WORKLOAD_DOCS = f"{REPO_URL}/workloads/README.md"
REGISTRY_DOCS = f"{REPO_URL}/docs/landing-zone-sim.md"
REGISTRY = "platform/dev.yaml"

SUPPORTED = {
    "$schema", "$id", "title", "description", "type", "const", "enum", "pattern",
    "minimum", "maximum", "required", "properties", "additionalProperties",
    "propertyNames", "minProperties", "items", "maxItems",
}
TYPES = {"object": dict, "array": list, "string": str, "integer": int}
MISSING = object()


def field(path):
    """['spec', 'vmGroups', 0, 'size'] → spec.vmGroups[0].size"""
    out = ""
    for part in path:
        out += f"[{part}]" if isinstance(part, int) else f".{part}"
    return out.lstrip(".") or "(whole file)"


def allowed(schema):
    """Describe in plain words what a schema accepts."""
    if "const" in schema:
        return json.dumps(schema["const"])
    if "enum" in schema:
        return ", ".join(str(v) for v in schema["enum"])
    if schema.get("type") == "integer" and "minimum" in schema and "maximum" in schema:
        return f"whole numbers from {schema['minimum']} to {schema['maximum']}"
    if "description" in schema:
        return schema["description"]
    if "pattern" in schema:
        return f"text matching {schema['pattern']}"
    return {"object": "a mapping (key: value)", "array": "a list", "string": "text",
            "integer": "a whole number"}.get(schema.get("type"), "see docs")


def check(value, schema, path, errors):
    """Collect (path, bad value, allowed values) for every schema violation."""
    unknown = set(schema) - SUPPORTED
    if unknown:
        sys.exit(f"validate: schema keyword(s) {sorted(unknown)} at {field(path)} are not supported "
                 "by scripts/validate_workloads.py — extend the script before using them.")

    if "const" in schema and value != schema["const"]:
        return errors.append((path, value, allowed(schema)))
    if "enum" in schema and value not in schema["enum"]:
        return errors.append((path, value, allowed(schema)))
    if "type" in schema:
        # bool is a subclass of int in Python; `count: true` must not pass as a number.
        if not isinstance(value, TYPES[schema["type"]]) or isinstance(value, bool):
            return errors.append((path, value, allowed(schema)))
    if "pattern" in schema and not re.search(schema["pattern"], value):
        return errors.append((path, value, allowed(schema)))
    if ("minimum" in schema and value < schema["minimum"]) or ("maximum" in schema and value > schema["maximum"]):
        return errors.append((path, value, allowed(schema)))

    if isinstance(value, dict):
        props = schema.get("properties", {})
        for name in schema.get("required", []):
            if name not in value:
                errors.append((path + [name], MISSING, f"required — {allowed(props.get(name, {}))}"))
        if len(value) < schema.get("minProperties", 0):
            errors.append((path, value, f"at least {schema['minProperties']} entry"))
        for name, item in value.items():
            if "propertyNames" in schema and not re.search(schema["propertyNames"]["pattern"], name):
                errors.append((path + [name], name, f"a key matching {schema['propertyNames']['pattern']}"))
            if name in props:
                check(item, props[name], path + [name], errors)
            elif isinstance(schema.get("additionalProperties"), dict):
                check(item, schema["additionalProperties"], path + [name], errors)
            elif schema.get("additionalProperties") is False:
                errors.append((path + [name], "unknown field",
                               "only these fields: " + ", ".join(props)))
    if isinstance(value, list):
        if len(value) > schema.get("maxItems", len(value)):
            errors.append((path, f"{len(value)} entries", allowed(schema)))
        for i, item in enumerate(value):
            check(item, schema.get("items", {}), path + [i], errors)


class Report:
    def __init__(self, root):
        self.root = root
        self.errors = []

    def add(self, file, path, bad, allowed_values, docs=WORKLOAD_DOCS):
        self.errors.append({"file": file, "path": path, "bad": bad, "allowed": allowed_values, "docs": docs})

    def line(self, file, path):
        """Line of a field in the YAML file; for a missing field, the line of its parent."""
        while True:
            expr = "".join(f"[{p}]" if isinstance(p, int) else f'["{p}"]' for p in path) or "."
            got = subprocess.run(["yq", f"{expr if expr == '.' else '.' + expr} | line", str(self.root / file)],
                                 capture_output=True, text=True)
            if got.returncode == 0 and got.stdout.strip().isdigit() and int(got.stdout) > 0:
                return int(got.stdout)
            if not path:
                return 1
            path = path[:-1]

    def print(self):
        on_github = os.environ.get("GITHUB_ACTIONS") == "true"
        total = len(self.errors)
        for n, e in enumerate(self.errors, 1):
            bad = "(missing)" if e["bad"] is MISSING else e["bad"] if e["bad"] == "unknown field" else json.dumps(e["bad"])
            line = self.line(e["file"], e["path"]) if isinstance(e["path"], list) else 1
            name = field(e["path"]) if isinstance(e["path"], list) else e["path"]
            text = [
                f"File:           {e['file']} (line {line})",
                f"Field:          {name}",
                f"Bad value:      {bad}",
                f"Allowed values: {e['allowed']}",
                f"Docs:           {e['docs']}",
            ]
            print(f"\nERROR {n} of {total}\n  " + "\n  ".join(text))
            if on_github:
                print(f"::error file={e['file']},line={line},title=Invalid {name}::" + "%0A".join(text[2:]))
        if total:
            print(f"\nvalidate: {total} error(s). Nothing was planned or changed.")


def load(root, file, report):
    got = subprocess.run(["yq", "-o=json", ".", str(root / file)], capture_output=True, text=True)
    if got.returncode != 0:
        reason = got.stderr.strip().splitlines()[-1].removeprefix("Error: ")
        report.add(file, "(whole file)", reason, "valid YAML")
        return None
    return json.loads(got.stdout)


def main():
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    report = Report(root)
    schema = {name: json.loads((root / f"schema/{name}.schema.json").read_text()) for name in ("environment", "workload")}

    # --- registry --------------------------------------------------------------
    registry = load(root, REGISTRY, report)
    projects = {}
    if registry is not None:
        found = []
        check(registry, schema["environment"], [], found)
        for path, bad, ok in found:
            report.add(REGISTRY, path, bad, ok, REGISTRY_DOCS)
        if not found:
            projects = registry["projects"]
            for attr, get in (("projectId", lambda p: p["projectId"]), ("network.cidr", lambda p: p["network"]["cidr"])):
                seen = {}
                for key, project in projects.items():
                    if get(project) in seen:
                        report.add(REGISTRY, ["projects", key] + attr.split("."), get(project),
                                   f"a value not used by another project (already used by {seen[get(project)]})", REGISTRY_DOCS)
                    seen.setdefault(get(project), key)

    # --- workloads -------------------------------------------------------------
    files = sorted(p.relative_to(root).as_posix() for ext in ("yaml", "yml") for p in (root / "workloads").rglob(f"*.{ext}"))
    for file in files:
        parts = file.split("/")
        if len(parts) != 4 or parts[3] != "workload.yaml":
            report.add(file, "(file path)", file, "workloads/<team>/<env>/workload.yaml")
            continue
        team_dir, env_dir = parts[1], parts[2]
        workload = load(root, file, report)
        if workload is None:
            continue
        found = []
        check(workload, schema["workload"], [], found)
        for path, bad, ok in found:
            report.add(file, path, bad, ok)
        if not isinstance(workload, dict):
            continue
        meta = workload.get("metadata") if isinstance(workload.get("metadata"), dict) else {}
        spec = workload.get("spec") if isinstance(workload.get("spec"), dict) else {}

        # path rules: the folder decides who owns the file (CODEOWNERS), so it must agree with the content
        if "team" in meta and meta["team"] != team_dir:
            report.add(file, ["metadata", "team"], meta["team"], f"{team_dir} (the file is in workloads/{team_dir}/)")
        if "env" in meta and meta["env"] != env_dir:
            report.add(file, ["metadata", "env"], meta["env"], f"{env_dir} (the file is in workloads/{team_dir}/{env_dir}/)")

        # registry rules: only registered projects, and only the team's own
        key = spec.get("project")
        if isinstance(key, str) and projects:
            own = sorted(k for k, p in projects.items() if p["team"] == team_dir)
            if key not in projects:
                report.add(file, ["spec", "project"], key,
                           (", ".join(own) if own else f"none yet — no project is registered for team {team_dir}")
                           + f" (projects of team {team_dir} in {REGISTRY})", REGISTRY_DOCS)
            elif projects[key]["team"] != team_dir:
                report.add(file, ["spec", "project"], key,
                           (", ".join(own) if own else "none yet")
                           + f" ({key} belongs to team {projects[key]['team']}, not {team_dir})", REGISTRY_DOCS)

        groups = spec.get("vmGroups") if isinstance(spec.get("vmGroups"), list) else []
        names = [g.get("name") if isinstance(g, dict) else None for g in groups]
        for i, name in enumerate(names):
            if name is not None and name in names[:i]:
                report.add(file, ["spec", "vmGroups", i, "name"], name, "a name used only once in this file")

    report.print()
    if report.errors:
        sys.exit(1)
    print(f"validate: {REGISTRY} and {len(files)} workload file(s) are valid")


if __name__ == "__main__":
    main()
