# What a team may choose is small on purpose; everything else is a platform default.

variable "project_id" {
  description = "Team project the VMs run in"
  type        = string
}

variable "region" {
  description = "Region of the VMs; they are spread over its zones a, b, c"
  type        = string
}

variable "subnetwork" {
  description = "Subnet (id or self link) from the baseline layer"
  type        = string
}

variable "snapshot_policy" {
  description = "Name of the snapshot schedule (resource policy) from the baseline layer, in the same project and region"
  type        = string
}

variable "team" {
  description = "Owning team (label)"
  type        = string
}

variable "env" {
  description = "Environment (label)"
  type        = string
}

variable "name" {
  description = "Group name, e.g. web. Part of every VM name; renaming it destroys and recreates the VMs"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,14}$", var.name))
    error_message = <<-EOT
      Field: spec.vmGroups[].name
      Bad value: "${var.name}"
      Allowed values: lowercase letters, digits and "-", starting with a letter, at most 15 characters
      Docs: https://github.com/mofach90/platform-live/blob/main/docs/PLAN.md#3-architecture
    EOT
  }
}

variable "instance_count" {
  description = "Number of VMs in the group (count in workload.yaml)"
  type        = number

  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 5 && floor(var.instance_count) == var.instance_count
    error_message = <<-EOT
      Field: spec.vmGroups[name=${var.name}].count
      Bad value: ${var.instance_count}
      Allowed values: whole numbers from 1 to 5
      Docs: https://github.com/mofach90/platform-live/blob/main/docs/PLAN.md#3-architecture
    EOT
  }
}

variable "size" {
  description = "T-shirt size, mapped to a machine type by the platform"
  type        = string

  validation {
    condition     = contains(["small", "medium", "large"], var.size)
    error_message = <<-EOT
      Field: spec.vmGroups[name=${var.name}].size
      Bad value: "${var.size}"
      Allowed values: small, medium, large
      Docs: https://github.com/mofach90/platform-live/blob/main/docs/PLAN.md#3-architecture
    EOT
  }
}

variable "image" {
  description = "Operating system image from the platform allow-list"
  type        = string

  validation {
    condition     = contains(["debian-12"], var.image)
    error_message = <<-EOT
      Field: spec.vmGroups[name=${var.name}].image
      Bad value: "${var.image}"
      Allowed values: debian-12
      Docs: https://github.com/mofach90/platform-live/blob/main/docs/PLAN.md#3-architecture
    EOT
  }
}
