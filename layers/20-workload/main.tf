# Workload: the VM groups a team asked for in workloads/<team>/<env>/workload.yaml.
# Runs once per project (one state each), as planner@ / deployer@ of that project.

locals {
  registry = yamldecode(file("${path.module}/../../platform/dev.yaml"))
  project  = local.registry.projects[var.project_key]

  # The path is fixed by the registry: a team can only describe its own project.
  workload_path = "workloads/${local.project.team}/${local.registry.environment}/workload.yaml"
  workload_file = "${path.module}/../../${local.workload_path}"
  workload      = fileexists(local.workload_file) ? yamldecode(file(local.workload_file)) : null

  vm_groups = local.workload == null ? {} : { for g in local.workload.spec.vmGroups : g.name => g }
}

# Fails clearly if the baseline layer has not been applied for this project.
data "google_compute_subnetwork" "platform" {
  name   = "platform-${local.registry.region}"
  region = local.registry.region
}

module "vm_group" {
  # Released module, pinned by tag. Bump only through a pull request (plan shows the effect).
  source   = "git::https://github.com/mofach90/platform-modules.git//modules/vm-group?ref=v1.0.0"
  for_each = local.vm_groups

  project_id = local.project.projectId
  region     = local.registry.region
  subnetwork = data.google_compute_subnetwork.platform.id
  # Created by the baseline layer under this fixed name. Not looked up with a data source:
  # the plan of a pull request must work before the baseline of that same change is applied.
  snapshot_policy = "platform-daily"
  team            = local.project.team
  env             = local.registry.environment

  name           = each.key
  instance_count = each.value.count
  size           = each.value.size
  image          = each.value.image
}
