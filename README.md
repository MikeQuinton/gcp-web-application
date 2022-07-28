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
  * [VPC](https://cloud.google.com/vpc/docs/vpc)
  * [Instance Group](https://cloud.google.com/compute/docs/instance-groups)
  * [Load Balancing](https://cloud.google.com/load-balancing/docs/https)
  * [Cloud SQL Instance](https://cloud.google.com/sql/docs/mysql)
* [Ubuntu](https://ubuntu.com/)
  * [Ubuntu Minimal 22.04 LTS](https://cloud-images.ubuntu.com/daily/server/minimal/daily/jammy/current/)

## Project requirements

### Task 1

The below "application" is deployed within the GCP cloud environment using the help of several different services which can be seen in the list above. The below shell script is executed after a computer instance is configured and powered on. HTTP server used is apache2.

Some of the code using to help setup and display this application publicy can be seen in the below tasks.

```sh
#!/bin/bash

sudo apt-get update
sudo apt -y install apache2
sudo cat <<EOF > /var/www/html/index.html
<html><body><p>Hello World!</p></body></html>
```

---

### Task 2

The application is running on a private network with access to a database service. Using the VPC service I have created a seperate network with a single subnet using an IP address range allocated for private use only.

The SQL instance is on a seperate private for use range but will be able to communicate with the compute nodes via a peering route.

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

##### SQL Configuration

```hcl
# Private IP for SQL
resource "google_compute_global_address" "private_ip_address" {
  provider      = google-beta
  project       = var.project
  name          = "app-db-ip-address"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.app-network.id
}

# Connection for DB
resource "google_service_networking_connection" "private_vpc_connection" {
  provider                = google-beta
  network                 = google_compute_network.app-network.id
  service                 = var.services[5]
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

# Creating SQL instance
resource "google_sql_database_instance" "app-sql" {
  name                = local.cloud_sql_instance_name
  database_version    = var.database_version
  region              = var.region
  project             = var.project
  deletion_protection = false
```

---

### Task 3

A highly available and scalable application.

Utilising a [MIG module](https://registry.terraform.io/modules/terraform-google-modules/vm/google/latest/submodules/instance_template) to help create and manange an instance template to deploy on the desired network.

Some of the benefits of the below are detailed below.

##### High availabilty

If an instance crashes, or is otherwise deleted by incorrect method. Another instance is automatically created in accordance with the specific template seen below and added to the group.

Application based healing. If an application does not respond on a VM via specific port, etc... it will automatically recreate the VM.

A MIG configured on a region will help spread VM's across multiple availability zones helping avoid outages and protecting against zonal failures. Example being the below case. A cooling failure in one of the buldings that hosts infrastructure for europe-west2-a with multiple services impacted this looks to have caused outages on compute engine and additional services.

https://status.cloud.google.com/incidents/XVq5om2XEDSqLtJZUvcH

##### Scalability 

When additional resources are required through utilisation, or traffic. VM's can be autoscaled to grow the number instances to meet demand. Additionally, if demand drops, this is automatically scaled down to reduce costs and allow for elasticisty.


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

To better understand this we can enable metrics, budgets and alerts to give us the overview of where funds are being spent within GCP and assess any of the costs. If required we can implement some of the below to bring these down.

I believe this can be tackled from a few different persepectives. One being the set resource allocation on the managed instance groups. When the instances are built they are being allocated a set amount of resources, so lets say for example 1 vCPU and 2 GiB's of memory. The application itself in runtime might not be using that amount of resources to it's full capacity and may only need half or a quarter of this depending on what it requires. This could be tackled with a serverless application where in you may only be required to pay for the compute usage, so the the cpu and the ram that the application is using.

If we are looking to stick with the current managed instance group service we can specifically look to lower the tier on certain resources such the instance type and disk type. We can even go as far creating a custom image type with the specific requirements of what is needed, so cpu, memory, storage, network, etc...

Another possible route is instance uptime. If the application is not required to be up 24 hours, so if the client is not working over weekends or nights and depending on the application itself it could possible to schedule an auto start and stop for the VM's.

---

### Task 5

Secure and compliant application

Below are some of the steps that can are currently put in place to help achieve compliance and to help establish and improve customer trust.

##### Least privilege

Any service accounts, or user accounts that are setup can be configured with access to resources that they are only required to have. If they are developer, or a support engineer it configured in a way that they can only have to these specific resources, such as cloud build, or compute instances. An additional step to this can be to confifure custom policies to adjust permissions from a more granular perspecitive, this can be great if we only want someone to be able to access a resource and only have the ability to perform a specific task. An example in this case, is only being able to adjust the status of a compute resources, so being able to start, stop or restart an instance.

The root account used to setup and reqister with GCP cloud shouldn't be used by anyone as this has full explicit access to every resource within GCP. Only accounts that have privileges implicitly applied should be used.

##### MFA

Further on from the above point we can also enforce 2FA on user accounts to provide an extra layer of security when accessing the GCP environment. This should be enabled for every account, including the root account.

##### Cloud Armour

Used to lockdown the application via a WAF. On this we currently have an default rule enabled which comes with some preconfigured rules for XSS, SQLi, LFI, etc... some of these will come into action if required. Example, if the application requires protection from SQL injection, we can reference a preconfigured rule to fine tune what is needed.

I can also detail where specific connections should be coming from by adding a spefic public IP address, or range of public IP addresses. If the client is only required is only required to access this application, along with ourselves from admin overview perspective. We can set this in the source IP address range.

##### Firewall

Specific rules have been setup to only allow connections on specific ports on the network to avoid any unwanted connections, or applications / services that otherwise do not need to be publicy available or accessed.

In this case port 80 is the only port publicly available for access as this required to reach the web application via a connection through the external HTTP load balancer.

##### IAP

For administrative access to the VM's, IAP has been enabled on the environment. So via TCP forwarding I can access the VM's via SSH on the internal network instead of using an external IP address. None of the VM's will have an external IP address allocated and this service helps prevent them being publicy exposed to the internet.

##### Cloud DLP

This can be used from a data exfiltration perspective to scan storage repositories for potential sensitive data within the project environment, such as credit cards, names, ages, addresses, etc...

##### VPC Service Controls

Using VPC service controls we can setup a security perimiter around the environment blocking any external access by default unless otherwise implicitly allowed. So if a storage bucket is configured and policies are incorrectly set due to human error, in turn making this publicy accessible. VPC service will block ingress traffic, even if policies allow it.

---

## Contact

Michael Quinton

[![LinkedIn][linkedin-shield]][linkedin-url]

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
