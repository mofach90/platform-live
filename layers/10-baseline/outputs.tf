output "network" {
  description = "VPC of the team project"
  value       = google_compute_network.platform.id
}

output "subnetwork" {
  description = "Subnet for platform VMs"
  value       = google_compute_subnetwork.platform.id
}

output "snapshot_policy" {
  description = "Daily snapshot schedule that platform VMs are attached to"
  value       = google_compute_resource_policy.daily_snapshots.name
}
