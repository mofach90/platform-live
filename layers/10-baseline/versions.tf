terraform {
  required_version = "~> 1.17.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.10"
    }
  }

  # One state per project: the prefix is passed at init time,
  # -backend-config="prefix=baseline/<project key>" (see Makefile).
  backend "gcs" {
    bucket = "platform-project-dev-514319-tfstate"
  }
}

# Every call runs as planner@ or deployer@ of the team project. The backend is
# not affected by this argument: state access keeps the caller's own identity.
provider "google" {
  project                     = local.project.projectId
  region                      = local.registry.region
  impersonate_service_account = "${var.identity}@${local.project.projectId}.iam.gserviceaccount.com"
}
