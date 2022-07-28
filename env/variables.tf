locals {
  gcp_service_account_name = "${var.project}-svc"
  cloud_sql_instance_name  = "${var.project}-db"
  mig_instance_name        = "app-flask-vm-dev"
}

variable "region" {
  type        = string
  description = "Default region used for deployment"
  default     = "europe-west2"
}

variable "zone" {
  type        = string
  description = "Default zone used for deployment"
  default     = "europe-west2-c"
}


variable "project" {
  type        = string
  description = "Name of the project"
  default     = "apps-web-app-dev"
}

variable "network_name" {
  type        = string
  description = "Name for the VPC network"
  default     = "app-network-dev"
}

variable "subnet_range" {
  type        = string
  description = "IP range for the subnet"
  default     = "10.10.10.0/24"
}
variable "subnet_name" {
  type        = string
  description = "Name for the subnet"
  default     = "app-subnet-dev"
}

variable "database_version" {
  type        = string
  description = "Database version for app"
  default     = "MYSQL_8_0"
}

variable "database_tier" {
  type        = string
  description = "Database tier for app"
  default     = "db-f1-micro"
}

variable "database_name" {
  type        = string
  description = "Name of database for app"
  default     = "app-db-dev"
}

variable "machine_type" {
  type        = string
  description = "Compute type to deploy"
  default     = "e2-medium"
}

variable "source_image_family" {
  type        = string
  description = "Source image family. If neither source_image nor source_image_family is specified, defaults to the latest public Ubuntu image."
  default     = "ubuntu-minimal-2204-lts"
}

variable "source_image_project" {
  type        = string
  description = "Project where the source image comes from"
  default     = "ubuntu-os-cloud"
}

variable "mig_size" {
  type        = number
  description = "Number of instances"
  default     = 1
}

variable "services" {
  type        = list(string)
  description = "List of services to enable for project"
  default = [
    "compute.googleapis.com",
    "appengine.googleapis.com",
    "appengineflex.googleapis.com",
    "cloudbuild.googleapis.com",
    "secretmanager.googleapis.com",
    "servicenetworking.googleapis.com",
    "iam.googleapis.com",
    "storage.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com"
  ]
}

variable "policy_name" {
  default = "apps-waf-policy-dev"
  description = "Name of the default policy used by cloud armour"
  type = string
}
