# After `terraform apply` succeeds, these print to the terminal —
# also retrievable any time with `terraform output`.

output "instance_id" {
  description = "OCID of the created compute instance"
  value       = oci_core_instance.free_tier_vm.id
}

output "public_ip" {
  description = "Public IP address of the instance"
  value       = oci_core_instance.free_tier_vm.public_ip
}

output "private_ip" {
  description = "Private IP address of the instance within the VCN"
  value       = oci_core_instance.free_tier_vm.private_ip
}

output "ssh_command" {
  description = "Ready-to-copy SSH command"
  value       = "ssh -i ~/.ssh/id_ed25519 ubuntu@${oci_core_instance.free_tier_vm.public_ip}"
}

output "app_url" {
  description = "URL for whatever you run on var.app_port, once it's up"
  value       = "http://${oci_core_instance.free_tier_vm.public_ip}:${var.app_port}"
}

output "vcn_id" {
  description = "OCID of the created VCN"
  value       = oci_core_vcn.main.id
}

output "subnet_id" {
  description = "OCID of the created subnet"
  value       = oci_core_subnet.public.id
}
