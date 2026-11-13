# Baseline: what every registered team project gets before workloads can run.
# Runs once per project (one state each), as planner@ / deployer@ of that project.

locals {
  registry = yamldecode(file("${path.module}/../../platform/dev.yaml"))
  project  = local.registry.projects[var.project_key]

  apis = toset([
    "compute.googleapis.com",
    "iap.googleapis.com",
    "oslogin.googleapis.com",
  ])
}

resource "google_project_service" "apis" {
  for_each = local.apis

  service            = each.value
  disable_on_destroy = false
}

# --- Network: private only ------------------------------------------------------

resource "google_compute_network" "platform" {
  name                    = "platform"
  auto_create_subnetworks = false

  depends_on = [google_project_service.apis]
}

# Private Google Access: VMs without external IP still reach Google APIs.
resource "google_compute_subnetwork" "platform" {
  name                     = "platform-${local.registry.region}"
  network                  = google_compute_network.platform.id
  ip_cidr_range            = local.project.network.cidr
  private_ip_google_access = true
}

# Cloud NAT: outbound internet (package updates) without inbound exposure.
resource "google_compute_router" "platform" {
  name    = "platform"
  network = google_compute_network.platform.id
}

resource "google_compute_router_nat" "platform" {
  name                               = "platform"
  router                             = google_compute_router.platform.name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# The only way in: SSH through IAP TCP forwarding (Google's fixed source range).
resource "google_compute_firewall" "allow_iap_ssh" {
  name        = "platform-allow-iap-ssh"
  network     = google_compute_network.platform.id
  description = "SSH only from Identity-Aware Proxy TCP forwarding"
  direction   = "INGRESS"

  source_ranges = ["35.235.240.0/20"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

# --- OS Login: SSH access is decided by IAM, not by keys in metadata ------------

resource "google_compute_project_metadata_item" "oslogin" {
  key   = "enable-oslogin"
  value = "TRUE"

  depends_on = [google_project_service.apis]
}

# --- Backup: one daily snapshot schedule per project ----------------------------
# The vm-group module attaches every boot disk to it by this name, so teams get
# backups without asking.

resource "google_compute_resource_policy" "daily_snapshots" {
  name        = "platform-daily"
  description = "Daily disk snapshot, kept 7 days"

  snapshot_schedule_policy {
    schedule {
      daily_schedule {
        days_in_cycle = 1
        start_time    = "03:00" # UTC
      }
    }

    # Snapshots also expire after the VM is deleted: no forgotten backups to pay for.
    retention_policy {
      max_retention_days    = 7
      on_source_disk_delete = "APPLY_RETENTION_POLICY"
    }

    snapshot_properties {
      storage_locations = [local.registry.region]
      labels = {
        managed-by = "platform"
      }
    }
  }

  depends_on = [google_project_service.apis]
}
