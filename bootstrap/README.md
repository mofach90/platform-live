# bootstrap

Central setup that CI needs before it can run: Workload Identity Federation,
the `ci-plan` / `ci-apply` service accounts, the state bucket, and the
impersonation grants for every project in `platform/dev.yaml`.

**Applied by a human only, never by CI.** This code manages CI's own rights; a
pipeline that could change them could lock itself out or give itself more.

## First apply (local state)
```bash
cd bootstrap
terraform init
terraform plan
terraform apply
```
State is a local file (`terraform.tfstate`, gitignored) because the bucket that
should hold it does not exist yet.

## Move the state into the bucket (once, right after the first apply)
Create `bootstrap/backend.tf`:
```hcl
terraform {
  backend "gcs" {
    bucket = "platform-project-dev-514319-tfstate"
    prefix = "bootstrap"
  }
}
```
Then:
```bash
terraform init -migrate-state      # answer "yes" to copy the local state
terraform plan                     # must print "No changes"
gcloud storage ls gs://platform-project-dev-514319-tfstate/bootstrap/
rm terraform.tfstate terraform.tfstate.backup
```
Commit `backend.tf`.

## Onboarding a team project
1. Landing zone creates the project (`docs/landing-zone-sim.md`).
2. PR: add it to `platform/dev.yaml`. Its plan jobs for the new project fail at first:
   CI has no rights in that project yet.
3. From the PR branch, a human runs `terraform apply` here. It adds exactly two grants
   (ci-plan → `planner@`, ci-apply → `deployer@` of the new project).
4. The same human runs `make plan LAYER=baseline PROJECT=<key>` and
   `make plan LAYER=workload PROJECT=<key>` once. The first plan of a new state
   creates an empty state file, and the PR identity (`ci-plan`) is read-only on the bucket.
5. Re-run the failed PR checks (`gh run rerun --failed`), review the plans, merge.
   The apply workflow then builds the baseline of the new project.

## Do not destroy
A deleted workload identity pool stays soft-deleted for 30 days and its ID
cannot be reused in that time. The state bucket has `prevent_destroy`.
