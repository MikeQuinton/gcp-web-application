locals {
    gcp_service_account_name = "${var.gcp_project}-svc"
    cloud_sql_instance_name = "${var.gcp_project}-db"
}

variable "region" {
    type = string
    description = "Default region used for deployment"
    default = "europe-west2"
}

variable "zone" {
    type = string
    description = "Default zone used for deployment"
    default = "europe-west2-c"
}

variable "gcp_project" {
    type = string
    description = "Name of the project"
    default = "appsbroker-web-application"
}

variable "network_name" {
    type = string
    description = "Name for the VPC network"
    default = "app-network"
}

variable "subnet_range" {
  type        = string
  description = "IP range for the subnet"
  default     = "10.10.10.0/24"
}
variable "subnet_name" {
  type        = string
  description = "Name for the subnet"
  default     = "votr-subnet"
}

variable "database_version" {
    type = string
    description = "Database version for app"
    default = "MYSQL_8_0"
}

variable "database_tier" {
    type = string
    description = "Database tier for app"
    default = "db-f1-micro"
}

variable "database_name" {
    type = string
    description = "Name of database for app"
    default = "app-db"
}

variable "services" {
    type = list(string)
    description = "List of services to enable for project"
    default = [
        "compute.googleapis.com",
        "appengine.googleapis.com",
        "appengineflex.googleapis.com",
        "cloudbuild.googleapis.com",
        "secretmanager.googleapis.com",
        "servicenetworking.googleapis.com"
    ]
}