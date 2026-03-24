resource "google_compute_network" "main" {
  name                    = "${local.app_name}-vpc"
  auto_create_subnetworks = false

  depends_on = [google_project_service.apis]
}

resource "google_compute_subnetwork" "main" {
  name          = "${local.app_name}-subnet"
  network       = google_compute_network.main.id
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
}

resource "google_compute_global_address" "private_ip" {
  name          = "${local.app_name}-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.main.id
}

resource "google_service_networking_connection" "private" {
  network                 = google_compute_network.main.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip.name]

  depends_on = [google_project_service.apis]
}

resource "google_vpc_access_connector" "connector" {
  name          = "${local.app_name}-conn"
  region        = var.region
  ip_cidr_range = "10.8.0.0/28"
  network       = google_compute_network.main.name

  depends_on = [google_project_service.apis]
}
