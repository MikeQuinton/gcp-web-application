/*****************************************
  API'S
 *****************************************

# Enabling API's for deployment
resource "google_project_service" "service" {
    for_each = toset(var.services)
    service = each.key
    project = var.project
    disable_on_destroy = false
}

/*****************************************
  VPC and Firewall
 *****************************************/

# VPC for the application
resource "google_compute_network" "app-network" {
    name = var.network_name
    project = var.project
    auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "app-subnet" {
    project = var.project
    name = var.subnet_name
    ip_cidr_range = var.subnet_range
    region = var.region
    network = google_compute_network.app-network
}

resource "google_compute_router" "app-router" {
  name = "${var.network_name}-router"
  network = google_compute_network.app-network.self_link
  region = var.region
  project = var.project
}

resource "google_compute_router_nat" "app-nat" {
    project = var.project
    name = "${var.network_name}-nat"
    router = google_compute_router.app-router.name
    region = google_compute_router.app-router.region

    # NAT IP's allocated by GCP
    nat_ip_allocate_option = "AUTO_ONLY"

    # All IP's in all subnets within the VPC can be allowed to NAT
    source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

resource "google_compute_firewall" "http" {
    project = var.project
    name = "${var.network_name}-http-allow"
    network = google_compute_network.app-network.name
    description = "Firewall rule to allow HTTP traffic on target instances"

    allow {
      protocol = "tcp"
      ports = ["80"]
    }

    target_tags = ["allow-http"]

}

# Private IP for SQL
resource "google_compute_global_address" "private_ip_address" {
    provider = google-beta
    project = var.project
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
    name = local.cloud_sql_instance_namegit
    database_version = var.database_version
    region = var.region
    project = var.project
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
    instance = google_sql_database_instance.app-sql.name
    project = var.project
}

resource "random_password" "mysql_root" {
    length = 16
    special = true
}

# Creating built in root user
resource "google_sql_user" "root" {
    name = "root"
    instance = google_sql_database_instance.app-sql.name
    type = "BUILT_IN"
    project = var.project
    password = random_password.mysql_root.result
}

/*****************************************
  Service account and Secret manager
 *****************************************/

# Instance's service account for secrets manager
resource "google_service_account" "service_account" {
    account_id = local.gcp_service_account_name
    display_name = local.gcp_service_account_name
    project = var.project
}

resource "google_secret_manager_secret" "app-secret" {
    provider = google-beta
    project = var.project
    secret_id = "app-token"
}

resource "google_secret_manager_secret_version" "app-secret-version" {
    provider = google-beta
    secret = google_secret_manager_secret.app-secret.secret_id
    secret_data = jsonencode({
        "DB_USER" = "root"
        "DB_PASS" = random_password.mysql_root.result
        "DB_NAME" = var.database_name
        "DB_HOST" = "${google_sql_database_instance.app-sql.private_ip-address}:3306"
    })
}

resource "google_secret_manager_secret_iam_member" "app-secret-member" {
    provider = google-beta
    project = var.project
    secret_id = google_secret_manager_secret.app-secret.id
    role = "roles/secretmanager.secretAccessor"
    member = "serviceAccount:${google_service_account.service_account.email}"
}

/*****************************************
  MIG
 *****************************************/

 module "mig_template" {
    source = "terraform-google-modules/vm/google//modules/instance_template"
    version = "~> 7.0"
    project_id = var.project
    machine_type = var.machine_type
    network = var.network_name
    subnetwork = var.subnet_name
    subnetwork_project = var.project
    region = var.region
    service_account = {
        email = google_service_account.service_account.email
        scopes = [
            "https://www.googleapis.com/auth/cloud-platform"
        ]
    }

    disk_size_gb = 10
    disk_type = "pd_standard"
    auto_delete = true
    name_prefix = local.mig_instance_name
    source_image_family = var.source_image_family
    source_image_project = var.source_image_project
    
    metadata = {
        "secret-id" = google_secret_manager_secret_version.app-secret-version.name
    }

    tags = [
        "allow-http", "app-flask-vm"
    ]
 }
module "mig" {
    source = "terraform-google-modules/vm/google//modules/mig"
    version = "~> 7.0"
    project_id = var.project
    subnetwork_project = var.project
    hostname = local.mig_instance_name
    region = var.region
    instance = module.mig_template.self_link
    autoscaling_enabled = true
    cooldown_period = 60
}
