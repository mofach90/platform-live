# Central bootstrap: everything CI needs before it can run at all.
# Applied MANUALLY by a human (it manages CI's own rights — see ADR 0001 #3).

locals {
  registry    = yamldecode(file("${path.module}/../platform/dev.yaml"))
  github_repo = "mofach90/platform-live"

  # Members that may act as the CI service accounts, selected by token attributes.
  wif_any_ref = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${local.github_repo}"

  # Only this workflow file, running from main, may become ci-apply. A branch
  # check alone would let every workflow on main (PR pipeline, bots) through.
  apply_workflow_ref = "${local.github_repo}/.github/workflows/apply.yml@refs/heads/main"
  wif_apply_workflow = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.workflow_ref/${local.apply_workflow_ref}"
}

# --- Workload Identity Federation: GitHub OIDC token → Google identity ---------

resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github"
  display_name              = "GitHub Actions"
  description               = "Identities from GitHub Actions OIDC tokens"
}

resource "google_iam_workload_identity_pool_provider" "github_oidc" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-oidc"
  display_name                       = "GitHub OIDC"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  # Claims copied from the token so IAM bindings can select on them.
  attribute_mapping = {
    "google.subject"         = "assertion.sub"
    "attribute.repository"   = "assertion.repository"
    "attribute.ref"          = "assertion.ref"
    "attribute.workflow_ref" = "assertion.workflow_ref"
  }

  # Tokens from any other repository are rejected at the door.
  attribute_condition = "assertion.repository == '${local.github_repo}'"
}

# --- CI identities: read (any branch / PR) and write (apply.yml on main only) ---

resource "google_service_account" "ci_plan" {
  account_id   = "ci-plan"
  display_name = "CI plan (read-only, any branch)"
}

resource "google_service_account" "ci_apply" {
  account_id   = "ci-apply"
  display_name = "CI apply (write, main only)"
}

resource "google_service_account_iam_member" "ci_plan_wif" {
  service_account_id = google_service_account.ci_plan.name
  role               = "roles/iam.workloadIdentityUser"
  member             = local.wif_any_ref
}

resource "google_service_account_iam_member" "ci_apply_wif" {
  service_account_id = google_service_account.ci_apply.name
  role               = "roles/iam.workloadIdentityUser"
  member             = local.wif_apply_workflow
}

# --- Terraform state bucket -----------------------------------------------------

resource "google_storage_bucket" "tfstate" {
  name     = local.registry.stateBucket
  location = local.registry.region

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  # Keep the last 30 versions of each state file.
  lifecycle_rule {
    condition {
      with_state         = "ARCHIVED"
      num_newer_versions = 30
    }
    action {
      type = "Delete"
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_storage_bucket_iam_member" "ci_plan_state" {
  bucket = google_storage_bucket.tfstate.name
  role   = "roles/storage.objectViewer"
  member = google_service_account.ci_plan.member
}

resource "google_storage_bucket_iam_member" "ci_apply_state" {
  bucket = google_storage_bucket.tfstate.name
  role   = "roles/storage.objectAdmin"
  member = google_service_account.ci_apply.member
}

# --- Impersonation grants, one pair per registered project ----------------------
# planner@ and deployer@ are created by the landing zone; the key is the registry
# project key (stable, name-based).

resource "google_service_account_iam_member" "ci_plan_planner" {
  for_each = local.registry.projects

  service_account_id = "projects/${each.value.projectId}/serviceAccounts/planner@${each.value.projectId}.iam.gserviceaccount.com"
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = google_service_account.ci_plan.member
}

resource "google_service_account_iam_member" "ci_apply_deployer" {
  for_each = local.registry.projects

  service_account_id = "projects/${each.value.projectId}/serviceAccounts/deployer@${each.value.projectId}.iam.gserviceaccount.com"
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = google_service_account.ci_apply.member
}
