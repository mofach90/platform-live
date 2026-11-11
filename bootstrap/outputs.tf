# Values the GitHub workflows need (not secrets).

output "workload_identity_provider" {
  description = "Full provider name for google-github-actions/auth"
  value       = google_iam_workload_identity_pool_provider.github_oidc.name
}

output "ci_plan_service_account" {
  description = "Service account for PR pipelines"
  value       = google_service_account.ci_plan.email
}

output "ci_apply_service_account" {
  description = "Service account for the apply pipeline on main"
  value       = google_service_account.ci_apply.email
}

output "state_bucket" {
  description = "Bucket that holds all Terraform state"
  value       = google_storage_bucket.tfstate.name
}

# output "debug" {
#   description = "my own debug"
#   value       = local.registry
# }
