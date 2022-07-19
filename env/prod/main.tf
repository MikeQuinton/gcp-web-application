/*****************************************
  API'S
 *****************************************/

# Enabling API's for deployment
resource "google_project_service" "service" {
    for_each = toset(var.services)
    service = each.key
    project = var.project
    disable_on_destroy = false
}

/*****************************************
  Service Account
 *****************************************/  

resource "google_service_account" "service_account" {
    account_id = local.gcp_service_account_name
    display_name = local.gcp_service_account_name
    project = var.project
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
    network = google_compute_network.app-network.name
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
  project     = var.project
  name        = "${var.network_name}-http-allow"
  network     = google_compute_network.app-network.name
  description = "Firewall rule to allow HTTP traffic on target instances"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  target_tags = ["allow-http"]
  source_tags = ["web-http"]
}

resource "google_compute_firewall" "ssh" {
  project     = var.project
  name        = "${var.network_name}-iap-allow"
  network     = google_compute_network.app-network.name
  description = "Firewall rule to allow SSH traffic through IAP on target instances"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  target_tags   = ["allow-ssh"]
  source_ranges = ["35.235.240.0/20"]
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
    name = local.cloud_sql_instance_name
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
  Managed Instance Group
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
    startup_script = file("startup.sh")
    service_account = {
        email = google_service_account.service_account.email
        scopes = [
            "https://www.googleapis.com/auth/cloud-platform"
        ]
    }

    disk_size_gb = 15
    disk_type = "pd-standard"
    auto_delete = true
    name_prefix = local.mig_instance_name
    source_image_family = var.source_image_family
    source_image_project = var.source_image_project

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
    instance_template = module.mig_template.self_link
    autoscaling_enabled = true
    cooldown_period = 60
}

/*****************************************
  Load Balancer
 *****************************************/

module "lb-http" {
  source  = "GoogleCloudPlatform/lb-http/google"
  version = "6.2.0"
  name = "${var.network_name}-lb"
  project = var.project
  target_tags = [
    google_compute_router.app-router.name,
    google_compute_subnetwork.app-subnet.name
  ]
  
  firewall_networks = [google_compute_network.app-network.name]

  backends = {
    default = {
        description = null
        protocol = "HTTP"
        port = 80
        port_name = "http"
        timeout_sec = 10
        connection_draining_timeout_sec = null
        enable_cdn = false
        security_policy = null
        session_affinity = null
        affinity_cookie_ttl_sec = null
        custom_request_headers = null
        custom_response_headers = null

        health_check = {
            check_interval_sec = null
            timeout_sec = null
            healthy_threshold = null
            unhealthy_threshold = null
            request_path = "/"
            port = 80
            host = null
            logging = null
        }

        log_config = {
            enable = true
            sample_rate = 1.0
        }

        groups = [
            {
                group = module.mig.instance_group
                balancing_mode  = null
                capacity_scaler = null
                description = null
                max_connections = null
                max_connections_per_instance = null
                max_connections_per_endpoint = null
                max_rate = null
                max_rate_per_instance = null
                max_rate_per_endpoint = null
                max_utilization = null
            },
        ]

        iap_config = {
            enable = false
            oauth2_client_id = ""
            oauth2_client_secret = ""
        }
    }
  }
}
