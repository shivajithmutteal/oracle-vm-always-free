# Oracle Cloud API credentials
# See README.md → "Get your API credentials" for where each of these
# comes from in the Oracle Cloud console.

variable "tenancy_ocid" {
  description = "OCID of your Oracle Cloud tenancy"
  type        = string
  sensitive   = true
}

variable "user_ocid" {
  description = "OCID of your Oracle Cloud user"
  type        = string
  sensitive   = true
}

variable "fingerprint" {
  description = "Fingerprint of your API signing key"
  type        = string
  sensitive   = true
}

variable "private_key_path" {
  description = "Path to your Oracle Cloud API private key file"
  type        = string
  sensitive   = true
  default     = "~/.oci/oci_api_key.pem"
}

variable "region" {
  description = "Oracle Cloud region to deploy in (must be your home region for Always Free — see README)"
  type        = string
  default     = "ap-hyderabad-1"
}

variable "compartment_ocid" {
  description = "OCID of the compartment to deploy into (typically your root/home compartment)"
  type        = string
  sensitive   = true
}

# Availability domain
variable "availability_domain_index" {
  description = "Which availability domain to use (0 = AD-1, 1 = AD-2, 2 = AD-3). If you hit 'out of capacity', try a different index."
  type        = number
  default     = 0

  validation {
    condition     = var.availability_domain_index >= 0 && var.availability_domain_index <= 2
    error_message = "Availability domain index must be 0, 1, or 2."
  }
}

# Network
variable "vcn_name" {
  description = "Name for the VCN"
  type        = string
  default     = "free-tier-vcn"
}

variable "vcn_cidr" {
  description = "CIDR block for the VCN"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_name" {
  description = "Name for the public subnet"
  type        = string
  default     = "free-tier-public-subnet"
}

variable "subnet_cidr" {
  description = "CIDR block for the subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "app_port" {
  description = "TCP port to open publicly for whatever app you run on the VM (change to match your app, e.g. 8080, 443 — or edit main.tf to remove this rule entirely if you don't need one)"
  type        = number
  default     = 3000
}

# Instance
variable "instance_name" {
  description = "Display name for the compute instance"
  type        = string
  default     = "free-tier-vm"
}

variable "instance_shape" {
  description = "Shape for the Always Free compute instance"
  type        = string
  default     = "VM.Standard.A1.Flex"

  validation {
    condition     = var.instance_shape == "VM.Standard.A1.Flex"
    error_message = "Only VM.Standard.A1.Flex (Ampere ARM) is supported on Always Free tier."
  }
}

variable "instance_ocpu" {
  description = "Number of OCPUs to allocate. Always Free allows up to 4, but Oracle cut new-account defaults to 2 in mid-2026 — check the console's live 'Always Free-eligible' indicator rather than assuming 4."
  type        = number
  default     = 4

  validation {
    condition     = var.instance_ocpu >= 1 && var.instance_ocpu <= 4
    error_message = "OCPU must be between 1 and 4 for Always Free tier."
  }
}

variable "instance_memory_gb" {
  description = "Memory in GB to allocate. Always Free allows up to 24, but recent accounts may be capped at 12 — check the console."
  type        = number
  default     = 24

  validation {
    condition     = var.instance_memory_gb >= 1 && var.instance_memory_gb <= 24
    error_message = "Memory must be between 1 and 24 GB for Always Free tier."
  }
}

variable "hostname_label" {
  description = "Hostname label for the instance"
  type        = string
  default     = "free-tier-vm"
}

# SSH
variable "ssh_public_key_path" {
  description = "Path to your SSH public key file, used to log into the VM after creation"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}
