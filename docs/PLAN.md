# PLAN — DevFest Berlin 2026 demo platform

## 1. The promise (accepted abstract)
"From Pull Request to Running App: Building a Small Platform on Google Cloud"
Regular talk, ~40 min incl. live demo, Sat 14 Nov 2026 10:00, Room 3 (Cloud + Backend).

Must show live: a team describes infrastructure in YAML and opens a PR →
validation → Terraform plan → deployment to **private** Compute Engine VMs;
CI authenticates with **Workload Identity Federation**, no SA keys; an
**invalid** configuration and how the platform reports it; discussion of what
developers control, which defaults the platform enforces, useful feedback.

## 2. Who does what (the core story of the talk)

| Actor | Responsibility | In this demo |
|-------|----------------|--------------|
| Landing zone | org/folders, create project, billing, base APIs, `deployer` (write) + `planner` (read) SAs | **manual**, `docs/landing-zone-sim.md`; on stage: "a real LZ does this" |
| Platform team — central | WIF, CI identities, state bucket, impersonation grants | `bootstrap/`, manual apply (chicken-and-egg) |
| Platform team — onboarding | register project in `platform/dev.yaml` (PR) + re-run bootstrap for the grants | PR + one manual apply |
| Platform team — baseline | configure each registered project: APIs, network, OS Login, snapshot policy | `layers/10-baseline`, CI |
| App team | `workloads/<team>/<env>/workload.yaml` → PR | `layers/20-workload`, CI |

## 3. Architecture

```
GitHub: platform-live
 ├─ platform/dev.yaml ───────────────┐ registry (platform team, CODEOWNERS)
 ├─ workloads/shop/dev/workload.yaml ┤ (app team, CODEOWNERS)
 │                                   ▼
 │  pr.yml   validate (schema + registry + path) → fmt/lint/trivy
 │           → changed projects → matrix: plan 10-baseline / 20-workload per project
 │           → one PR comment (updated, not duplicated)
 │  apply.yml (main): matrix baseline → matrix workload, concurrency per project+layer
 │
 └─ WIF (GitHub OIDC) ─► platform project platform-project-dev-514319
                          ci-plan  ──impersonates──► planner@<team project>   (read)
                          ci-apply ──impersonates──► deployer@<team project>  (write, main only)
                          state bucket: baseline/<key>, workload/<key>

team project (created by LZ): VPC + NAT + IAP fw (baseline) ─ private VMs (workload)

GitHub: platform-modules  (from step 8)
 merge → semantic-release tag vX.Y.Z → Renovate PR bumps ?ref= in platform-live
```

### Why per-project runs (matrix) for baseline AND workload
Each project is reached through its own impersonated SA. A Terraform provider's
identity is fixed per provider block and cannot vary inside one `for_each`, so
the pipeline runs one Terraform execution per project and sets
`GOOGLE_IMPERSONATE_SERVICE_ACCOUNT` per run. Bonus: separate state and blast
radius per tenant. (Same reason large platforms "fan out".)

### Registry (`platform/dev.yaml`)
```yaml
apiVersion: platform.demo/v1
kind: Environment
environment: dev
platformProject: platform-project-dev-514319
region: europe-west10
stateBucket: platform-project-dev-514319-tfstate
projects:
  shop-dev:                          # project key used by workloads
    projectId: shop-dev-7d94 # created by the landing zone
    team: shop
    network: { cidr: 10.10.0.0/24 }
```

### Workload contract (`workloads/shop/dev/workload.yaml`)
```yaml
apiVersion: platform.demo/v1
kind: Workload
metadata: { team: shop, env: dev }
spec:
  project: shop-dev       # must exist in platform/dev.yaml and belong to team "shop"
  vmGroups:
    - name: web           # for_each key — renaming = destroy + create
      count: 2            # 1..5
      size: small         # small|medium|large → e2-small|e2-medium|e2-standard-2
      image: debian-12    # allow-list → debian-cloud/debian-12
```
Validation layers: (1) JSON schema (shape, enums, ranges), (2) registry + path
rules in `scripts/validate_workloads.py`, (3) Terraform `validation`/`precondition`,
(4) Trivy policy scan. Each layer produces file/field/value/allowed/link messages.

### Identity
- WIF pool `github`, provider `github-oidc`, issuer
  `https://token.actions.githubusercontent.com`, attribute condition
  `assertion.repository == 'mofach90/platform-live'`, mapped attributes
  include `attribute.ref`.
- `ci-plan`: any branch/PR; `storage.objectViewer` on state bucket;
  `serviceAccountTokenCreator` on every `planner@`. Plans run with `-lock=false`.
- `ci-apply`: only `attribute.workflow_ref == mofach90/platform-live/.github/workflows/apply.yml@refs/heads/main`
  (the apply workflow on main, ADR 0002 #7); `storage.objectAdmin`
  on state bucket; `serviceAccountTokenCreator` on every `deployer@`.
- `main` is protected (PR + review required) — otherwise the ref condition is worthless.
- Humans locally: own ADC, may impersonate `planner@` for `make plan`.
- AI agents: plan only (AGENTS.md rule 1).

## 4. Build order (walking skeleton — pipeline green after each step)

| # | Increment | Done when |
|---|-----------|-----------|
| 0 | Day-1 checks; LZ-sim: teams folder + `shop-dev` project with deployer/planner (human) | `gcloud` impersonation of planner works |
| 1 | `bootstrap/`: WIF, ci-plan, ci-apply, state bucket, grants from registry; local state → migrate | bucket holds bootstrap state |
| 2 | `platform/dev.yaml` + schema; `layers/10-baseline` (APIs, VPC, subnet w/ Private Google Access, router+NAT, IAP firewall, OS Login metadata) | human applies once locally via deployer |
| 3 | `modules/vm-group` + `layers/20-workload` | local plan shows VMs for shop-dev |
| 4 | `pr.yml`: validate → changed-projects matrix → plans → single PR comment | readable plan comment on a PR |
| 5 | `apply.yml`: main → baseline matrix → workload matrix; concurrency | merge creates VMs; IAP SSH works |
| 6 | Friendly errors (schema + registry + path) | invalid PR shows clear red messages |
| 7 | Snapshot policy "daily" in baseline + disk attachment in vm-group | disks show schedule |
| 8 | Move modules to `platform-modules`, pin `?ref=v1.0.0` | plan "no changes" after move |
| 9 | semantic-release (tag + GitHub Release, no commit back) | `feat:` merge → new tag |
| 10 | Renovate GitHub App | PR "update vm-group to v1.1.0" appears |
| 11 | Trivy + tflint + gitleaks in pr.yml | findings in PR |
| 12 | Optional 2nd team project (`blog-dev`) to show matrix + isolation | 2 parallel plans |
| 13 | Reset script (VMs only — never projects) + recorded backup video | dry run from reset < 10 min |

Slides only ("how it grows up"): real landing zone / project factory, Shared VPC,
separate workloads repo, prod.yaml + promotion PRs, pinned runner image,
SonarQube for app code, drift detection, offboarding.

## 5. Schedule 


## 6. Day-1 checks (human runs; agents prepare commands)
```bash
gcloud auth login && gcloud auth application-default login
gcloud config set project platform-project-dev-514319
gcloud org-policies list --organization=$ORG_ID
gcloud org-policies describe iam.allowedPolicyMemberDomains --organization=$ORG_ID    # may block WIF principals
gcloud org-policies describe iam.workloadIdentityPoolProviders --organization=$ORG_ID # allowed OIDC issuers
gcloud org-policies describe compute.trustedImageProjects --organization=$ORG_ID
gcloud org-policies describe compute.vmExternalIpAccess --organization=$ORG_ID
gcloud compute machine-types list --filter="zone~europe-west10 AND name~'^e2-(small|medium|standard-2)$'"
gcloud billing projects list --billing-account=$BILLING_ACCOUNT_ID   # how many projects already linked
gcloud services enable iam.googleapis.com iamcredentials.googleapis.com sts.googleapis.com \
  cloudresourcemanager.googleapis.com storage.googleapis.com serviceusage.googleapis.com
```
Then `docs/landing-zone-sim.md`. Record every surprise in `docs/journal.md`.

## 7. Demo script
0. Before the talk: PR "shop: add web group" merged → apply done. Second PR ready.
1. **Who does what** slide → show `platform/dev.yaml` (registry), say "LZ created the project".
2. **Happy path**: open PR adding a `worker` group → checks → plan comment
   ("+3 to add") → merge → apply → console: VMs without external IP →
   `gcloud compute ssh <vm> --tunnel-through-iap --zone <zone>`.
3. **Invalid config** (branch ready): `project: payments-dev` (not registered),
   `size: huge`, `count: 50`, file in wrong folder → one clear message each.
4. **Rename trap** (bonus): `web` → `frontend` → plan shows destroy + create.
5. **Bots** (30 s): Renovate PR + GitHub Release from semantic-release.


## 8. Patterns
Separation of responsibilities (LZ / platform / team) · self-service via a
declarative contract · schema as API · registry as gate · golden-path defaults ·
GitOps (PR = request, merge = approval) · plan as review artefact · keyless auth
(WIF) · split read/write identities · impersonation per tenant · fan-out with
state per tenant · stable identities (for_each keys) · SemVer from Conventional
Commits · pin + update by PR · shift-left scanning · walking skeleton.

