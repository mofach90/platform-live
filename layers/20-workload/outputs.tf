output "instances" {
  description = "VM name → zone, per group"
  value       = { for name, group in module.vm_group : name => group.instances }

  # The workload file must target the project it is stored under.
  precondition {
    condition     = local.workload == null || try(local.workload.spec.project, "") == var.project_key
    error_message = <<-EOT
      File: ${local.workload_path}, field: spec.project
      Bad value: "${try(local.workload.spec.project, "(missing)")}"
      Allowed values: ${var.project_key} (the project this folder belongs to in platform/dev.yaml)
      Docs: https://github.com/mofach90/platform-live/blob/main/docs/PLAN.md#3-architecture
    EOT
  }
}
