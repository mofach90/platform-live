variable "project_key" {
  description = "Key of the team project in platform/dev.yaml, e.g. shop-dev"
  type        = string

  validation {
    condition     = contains(keys(local.registry.projects), var.project_key)
    error_message = <<-EOT
      File: platform/dev.yaml, field: projects
      Bad value: "${var.project_key}" is not a registered project.
      Allowed values: ${join(", ", keys(local.registry.projects))}
      Docs: https://github.com/mofach90/platform-live/blob/main/docs/landing-zone-sim.md
    EOT
  }
}

variable "identity" {
  description = "Service account of the team project to act as: planner (read) or deployer (write)"
  type        = string
  default     = "planner"

  validation {
    condition     = contains(["planner", "deployer"], var.identity)
    error_message = "Bad value for identity: \"${var.identity}\". Allowed values: planner, deployer."
  }
}
