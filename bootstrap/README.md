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
2. PR: add it to `platform/dev.yaml`.
3. After the merge, a human runs `terraform apply` here (adds the two grants).

## Do not destroy
A deleted workload identity pool stays soft-deleted for 30 days and its ID
cannot be reused in that time. The state bucket has `prevent_destroy`.
