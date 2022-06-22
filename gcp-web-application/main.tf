# Enabling API's for deployment
resource "google_project_service" "service" {
    for_each = toset(var.services)
    service = each.key
    project = var.gcp_project
    disable_on_destroy = false
}
 
# Instance's service account for secrets manager
resource "google_service_account" "service_account" {
    account_id = local.gcp_service_account_name
    display_name = local.gcp_service_account_name
    project = var.gcp_project
}

# VPC for the application
resource "google_compute_network" "app-network" {
    name = var.network_name
    project = var.gcp_project
    auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "app-subnet" {
    project = var.gcp_project
    name = var.subnet_name
    ip_cidr_range = var.subnet_range
    region = var.region
    network = google_compute_network.app-network
}

resource "google_compute_router" "default" {
  name = "${var.network_name}-router"
  network = google_compute_network.app-network.self_link
  region = var.region
  project = var.gcp_project
}

# Private IP for SQL
resource "google_compute_global_address" "private_ip_address" {
    provider = google-beta
    project = var.gcp_project
    name = "app-db-ip-address"
    purpose = "VPC_PEERING"
    address_type = "INTERNAL"
    prefix_length = 16
    network = google_compute_network.app-network.id
}

# Connection for DB
resource "google_service_networking_connection" "private_vpc_connection" {
    provider = google-beta
    network = google_compute_network.app-network.id
    service = var.services[5]
    reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

# Creating SQL instance
resource "google_sql_database_instance" "app-sql" {
    name = local.cloud_sql_instance_name
    database_version = var.database_version
    region = var.region
    project = var.gcp_project
    deletion_protection = false

    settings {

      tier = var.database_tier

      ip_configuration {
        ipv4_enabled = false
        private_network = google_compute_network.app-network.id
      }
    }

    depends_on = [
      google_service_networking_connection.private_vpc_connection
    ]
}

# Creating database on the SQL instance
resource "google_sql_database" "database" {
    name = var.database_name
    instance = google_sql_database_instance.app-sql
    project = var.gcp_project
}

resource "random_password" "mysql_root" {
    length = 16
    special = true
}
resource "google_sql_user" "root" {
    name = "root"
    instance = google_sql_database_instance.app-sql
    type = "BUILT_IN"
    project = var.gcp_project
    password = random_password.mysql_root.result
}
