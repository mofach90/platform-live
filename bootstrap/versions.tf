terraform {
  required_version = "~> 1.17.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.10"
    }
  }
}

# Runs with the human's own ADC (never in CI). user_project_override bills API
# calls to the platform project, which user credentials need for the IAM APIs.
provider "google" {
  project               = local.registry.platformProject
  region                = local.registry.region
  billing_project       = local.registry.platformProject
  user_project_override = true
}
