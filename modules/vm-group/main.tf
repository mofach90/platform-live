# A group of identical private VMs with the platform defaults built in.
# Teams cannot override: no external IP, IAP-only access, OS Login, Shielded VM,
# own service account, labels, names, daily snapshots.

locals {
  machine_types = {
    small  = "e2-small"
    medium = "e2-medium"
    large  = "e2-standard-2"
  }

  images = {
    "debian-12" = "debian-cloud/debian-12"
  }

  zone_suffixes = ["a", "b", "c"]

  # Stable, name-based keys ("01", "02", …): lowering the count removes the
  # highest numbers, raising it adds new ones, existing VMs are never touched.
  instances = {
    for i in range(var.instance_count) : format("%02d", i + 1) => {
      name = "${var.team}-${var.name}-${format("%02d", i + 1)}"
      zone = "${var.region}-${local.zone_suffixes[i % length(local.zone_suffixes)]}"
    }
  }

  labels = {
    team       = var.team
    env        = var.env
    group      = var.name
    managed-by = "platform"
  }

  # Minimal roles: the VMs may write logs and metrics, nothing else.
  service_account_roles = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
  ])
}

resource "google_service_account" "group" {
  project      = var.project_id
  account_id   = "vm-${var.name}"
  display_name = "VM group ${var.name} (${var.team}/${var.env})"
}

resource "google_project_iam_member" "group" {
  for_each = local.service_account_roles

  project = var.project_id
  role    = each.value
  member  = google_service_account.group.member
}

resource "google_compute_instance" "vm" {
  for_each = local.instances

  project      = var.project_id
  name         = each.value.name
  zone         = each.value.zone
  machine_type = local.machine_types[var.size]
  labels       = local.labels

  boot_disk {
    initialize_params {
      image = local.images[var.image]
      size  = 10
      type  = "pd-balanced"
    }
  }

  # No access_config block = no external IP.
  network_interface {
    subnetwork = var.subnetwork
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  metadata = {
    enable-oslogin         = "TRUE"
    block-project-ssh-keys = "TRUE"
  }

  service_account {
    email  = google_service_account.group.email
    scopes = ["cloud-platform"]
  }

  allow_stopping_for_update = true
}

# Backup by default: the boot disk (same name as the VM) follows the project's
# daily snapshot schedule. A separate resource, so adding it does not recreate VMs.
resource "google_compute_disk_resource_policy_attachment" "boot" {
  for_each = local.instances

  project = var.project_id
  name    = var.snapshot_policy
  disk    = google_compute_instance.vm[each.key].name
  zone    = each.value.zone
}
