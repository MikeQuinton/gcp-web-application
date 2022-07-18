<div id="top"></div>

[![LinkedIn][linkedin-shield]][linkedin-url]

<!-- PROJECT LOGO -->
<br />
<div align="center">
  <a href="https://github.com/github_username/repo_name">
    <img src="images/gcp.png" alt="Logo" width="160" height="80">
  </a>

<h3 align="center">GCP Web Application</h3>

  <p align="center">
    A terraform project that will deploy a scalable web application within Google Cloud.
  </p>
</div>

## About The Project

[![Product Name Screen Shot][product-screenshot]](https://example.com)

### Built With

* [Terraform](https://www.terraform.io/)
* [Google Cloud](https://cloud.google.com/)

## Project requirements

### Task 1

Public facing "Hello world" application

```sh
#!/bin/bash

sudo apt-get update
sudo apt -y install apache2
sudo cat <<EOF > /var/www/html/index.html
<html><body><p>Hello World!</p></body></html>
```

---

### Task 2

Application running on a private network with access to a database service.

##### VPC Configuration

```hcl
resource "google_compute_network" "app-network" {
  name                    = var.network_name
  project                 = var.project
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "app-subnet" {
  project       = var.project
  name          = var.subnet_name
  ip_cidr_range = var.subnet_range
  region        = var.region
  network       = google_compute_network.app-network.name
}

resource "google_compute_router" "app-router" {
  name    = "${var.network_name}-router"
  network = google_compute_network.app-network.self_link
  region  = var.region
  project = var.project
}

resource "google_compute_router_nat" "app-nat" {
  project = var.project
  name    = "${var.network_name}-nat"
  router  = google_compute_router.app-router.name
  region  = google_compute_router.app-router.region

  # NAT IP's allocated by GCP
  nat_ip_allocate_option = "AUTO_ONLY"

  # All IP's in all subnets within the VPC can be allowed to NAT
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
```

---

### Task 3

A highly available and scalable application

```hcl
module "mig_template" {
  source             = "terraform-google-modules/vm/google//modules/instance_template"
  version            = "~> 7.0"
  project_id         = var.project
  machine_type       = var.machine_type
  network            = var.network_name
  subnetwork         = true ? var.subnet_name : google_compute_subnetwork.app-subnet.self_link
  subnetwork_project = var.project
  region             = var.region
  startup_script     = file("startup.sh")
  service_account = {
    email = google_service_account.service_account.email
    scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  disk_size_gb         = 15
  disk_type            = "pd-standard"
  auto_delete          = true
  name_prefix          = local.mig_instance_name
  source_image_family  = var.source_image_family
  source_image_project = var.source_image_project

  tags = [
    "allow-http", "app-flask-vm", "allow-ssh"
  ]
}

module "mig" {
  source              = "terraform-google-modules/vm/google//modules/mig"
  version             = "~> 7.0"
  project_id          = var.project
  subnetwork_project  = var.project
  hostname            = local.mig_instance_name
  region              = var.region
  instance_template   = module.mig_template.self_link
  autoscaling_enabled = true
  cooldown_period     = 60
}
```

---

### Task 4

Cost effectiveness

---

### Task 5

Secure and compliant application

---

## Contact

Michael Quinton

<p align="right">(<a href="#top">back to top</a>)</p>

<!-- MARKDOWN LINKS & IMAGES -->
<!-- https://www.markdownguide.org/basic-syntax/#reference-style-links -->
[linkedin-shield]: https://img.shields.io/badge/-LinkedIn-black.svg?style=for-the-badge&logo=linkedin&colorB=555
[linkedin-url]: https://linkedin.com/in/mikepquinton
[product-screenshot]: images/screenshot.png




<!--
### Prerequisites

This is an example of how to list things you need to use the software and how to install them.
* npm
  ```sh
  npm install npm@latest -g
  ```

### Installation

1. Get a free API Key at [https://example.com](https://example.com)
2. Clone the repo
   ```sh
   git clone https://github.com/github_username/repo_name.git
   ```
3. Install NPM packages
   ```sh
   npm install
   ```
4. Enter your API in `config.js`
   ```js
   const API_KEY = 'ENTER YOUR API';
   ```
-->
