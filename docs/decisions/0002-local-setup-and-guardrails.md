# ADR 0002 — Local setup and landing-zone guardrails (2026-11-11)

Status: accepted.

| # | Decision | Why | Alternative considered |
|---|----------|-----|------------------------|
| 1 | Own gcloud directory for the demo: `.envrc` sets `CLOUDSDK_CONFIG=$HOME/.config/gcloud-devfest` and `GOOGLE_APPLICATION_CREDENTIALS` to the ADC file inside it (Terraform ignores `CLOUDSDK_CONFIG`) | Separate accounts, configs and ADC; the demo cannot touch other environments | Named gcloud configuration (does not isolate ADC) |
| 2 | Org, folder and billing IDs only in gitignored `.env`; docs use `$ORG_ID` etc. | Public, generic repo; forks work with their own values | Literal IDs in the docs |
| 3 | Landing zone grants the platform-team human `serviceAccountTokenCreator` on `planner@` and `deployer@` | Local plan and first apply need impersonation; Owner does not include it | Group + just-in-time access (real LZ; slide only) |
| 4 | `compute.vmExternalIpAccess` = deny on each team project, not on a folder | Another project in the nonprod folder needs external IPs | Policy on the `teams` folder (inherited by every new project) |
| 5 | `compute.skipDefaultNetworkCreation` enforced above the team projects; landing-zone script only verifies it | No `default` VPC with open SSH/RDP when the Compute API is enabled | Delete the default network after creation |
| 6 | `platform/dev.yaml` is created in step 1 (schema follows in step 2) | Bootstrap reads the registry for the impersonation grants | Hard-code the first project in bootstrap |
| 7 | ci-apply's WIF binding selects `attribute.workflow_ref` = `mofach90/platform-live/.github/workflows/apply.yml@refs/heads/main` | Branch alone is too broad: for `pull_request_target`, `workflow_dispatch`, `schedule` the ref is also `main`, so any workflow on main could become ci-apply. The apply workflow must keep the name `apply.yml` | Only `attribute.ref/refs/heads/main` (original plan); GitHub Environment with required reviewers (stronger, adds a manual click; slide only) |
