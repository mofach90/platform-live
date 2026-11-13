# Workloads — the contract for app teams

One file per team and environment: `workloads/<team>/<env>/workload.yaml`.
Open a pull request; the pipeline validates the file and shows the Terraform plan
as a comment. After the merge the platform creates the VMs.

```yaml
apiVersion: platform.demo/v1
kind: Workload
metadata: { team: shop, env: dev }
spec:
  project: shop-dev
  vmGroups:
    - name: web
      count: 2
      size: small
      image: debian-12
```

| Field | Allowed values | Notes |
|-------|----------------|-------|
| `metadata.team` | your team's folder name | must match the path |
| `metadata.env` | `dev` | must match the path |
| `spec.project` | a project key from `platform/dev.yaml` that belongs to your team | new project: see `docs/landing-zone-sim.md` |
| `vmGroups[].name` | lowercase letters, digits, `-`; starts with a letter; at most 15 characters; unique in the file | renaming a group destroys and recreates its VMs |
| `vmGroups[].count` | whole number from 1 to 5 | VMs are named `<team>-<name>-01`, `-02`, … |
| `vmGroups[].size` | `small` (e2-small), `medium` (e2-medium), `large` (e2-standard-2) | |
| `vmGroups[].image` | `debian-12` | platform allow-list |

What you get without asking: no external IP, outbound internet through NAT,
SSH only through IAP with OS Login, Shielded VM, one service account per group,
a daily disk snapshot kept for 7 days, labels for team, env and group.

Check locally before you push: `make validate`.
The machine-readable version of this table is `schema/workload.schema.json`.
