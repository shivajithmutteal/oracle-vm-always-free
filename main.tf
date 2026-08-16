# Oracle Cloud Always Free — Ampere A1 VM
#
# Creates the minimum infrastructure for a free-forever ARM VM:
# a VCN, a public subnet, security rules, and the compute instance
# itself. What you run on the VM afterwards (a RAG app, a personal
# server, anything) is up to you — this config only gets you the box.
#
# "Out of host capacity" errors are common on this shape (see README).
# Terraform does NOT retry those automatically — use retry-apply.sh
# or retry-apply.ps1 in this repo to keep trying until it succeeds.

terraform {
  required_version = ">= 1.0"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 5.0"
    }
  }
}

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}

# Virtual Cloud Network
resource "oci_core_vcn" "main" {
  compartment_id = var.compartment_ocid
  display_name   = var.vcn_name
  cidr_blocks    = [var.vcn_cidr]
  dns_label      = "maindns"
}

# Public subnet — the VM's NIC lives here
resource "oci_core_subnet" "public" {
  compartment_id     = var.compartment_ocid
  vcn_id             = oci_core_vcn.main.id
  display_name       = var.subnet_name
  cidr_block         = var.subnet_cidr
  route_table_id     = oci_core_route_table.public.id
  security_list_ids  = [oci_core_security_list.public.id]
  dns_label          = "public"

  # Required for the instance to get a public IP
  prohibit_public_ip_on_vnic = false
}

# Route table — sends internet-bound traffic through the gateway
resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "public-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.main.id
  }
}

# Internet gateway — required for the subnet to reach/be reached from the internet
resource "oci_core_internet_gateway" "main" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "main-igw"
  enabled        = true
}

# Security list — this is the cloud firewall. Note that Oracle VMs
# also ship with iptables/firewalld running locally (a second firewall
# layer) — see the README if a port is open here but still unreachable.
resource "oci_core_security_list" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "public-sl"

  # Outbound: allow everything
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }

  # Inbound: SSH
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    description = "SSH access"

    tcp_options {
      min = 22
      max = 22
    }
  }

  # Inbound: whatever app you're running (default 3000; change
  # var.app_port in terraform.tfvars, or delete this block if you
  # don't need a public app port at all)
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    description = "Application port (var.app_port)"

    tcp_options {
      min = var.app_port
      max = var.app_port
    }
  }
}

# The VM itself.
#
# If this fails with "Out of host capacity for shape VM.Standard.A1.Flex":
#   - It's expected — Ampere A1 Free Tier capacity is limited and shared
#     across every free-tier user in the region.
#   - Terraform will NOT retry this on its own. Re-run `terraform apply`,
#     or better, run ./retry-apply.sh (or .\retry-apply.ps1) which loops
#     `terraform apply` on an interval until it succeeds.
#   - See README.md → "Out of capacity" for the full explanation and
#     other things to try (different AD, different time of day).
resource "oci_core_instance" "free_tier_vm" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[var.availability_domain_index].name
  compartment_id      = var.compartment_ocid
  display_name        = var.instance_name
  shape                = var.instance_shape

  shape_config {
    ocpus         = var.instance_ocpu
    memory_in_gbs = var.instance_memory_gb
  }

  create_vnic_details {
    subnet_id              = oci_core_subnet.public.id
    assign_public_ip       = true
    hostname_label         = var.hostname_label
    skip_source_dest_check = false
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.ubuntu.images[0].id
  }

  metadata = {
    ssh_authorized_keys = file(var.ssh_public_key_path)
  }

  preserve_boot_volume = false

  lifecycle {
    create_before_destroy = true
  }
}

# Availability domains in this region — index into this list via
# var.availability_domain_index (0 = AD-1, 1 = AD-2, 2 = AD-3)
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

# Latest Ubuntu 24.04 ARM image available for the A1 shape
data "oci_core_images" "ubuntu" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04"
  shape                    = var.instance_shape

  state = "AVAILABLE"

  sort_by    = "TIMECREATED"
  sort_order = "DESC"
}
