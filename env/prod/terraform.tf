# Calling the GCP provider. Specifiying a source and version.
terraform {
  required_providers {
    google = {
        source = "hashicorp/google"
        version = "4.0"
    }
  }
}

terraform {
  backend "gcs" {
    bucket = "appsbroker-webapp-prod"
    prefix = "prod\tf-state"
  }
}

provider "google" {
    region = var.region
    zone = var.zone 
}

provider "google-beta" {
  region = var.region
  zone   = var.zone
}
