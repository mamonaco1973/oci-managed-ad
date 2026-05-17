# ==============================================================================
# Windows Active Directory - Module Invocation
# ------------------------------------------------------------------------------
# Purpose:
#   - Invokes the reusable OCI windows-ad module to deploy a Windows Server 2022
#     Active Directory Domain Controller.
#
# Notes:
#   - Ensure NAT gateway and route table associations exist before provisioning
#     (depends_on) — the DC bootstrap needs outbound internet for Windows Update
#     checks and role installation sources.
# ==============================================================================

module "windows_ad" {
  source = "../../module-oci-managed-ad"

  compartment_id = var.compartment_ocid
  tenancy_ocid   = var.tenancy_ocid

  # Domain identity
  netbios  = var.netbios
  realm    = var.realm
  dns_zone = var.dns_zone

  # Authentication
  administrator_password       = random_password.administrator_password.result
  admin_domain_password        = random_password.admin_domain_password.result
  windows_local_admin_password = random_password.windows_local_admin_password.result

  # Networking — DC on public subnet with public IP for debug access via RDP
  vcn_id                      = oci_core_vcn.ad_vcn.id
  vcn_default_dhcp_options_id = oci_core_vcn.ad_vcn.default_dhcp_options_id
  subnet_ocid                 = oci_core_subnet.vm_subnet.id
  assign_public_ip            = true

  depends_on = [
    oci_core_nat_gateway.ad_nat,
    oci_core_route_table.private_rt,
  ]
}

# ==============================================================================
# Outputs consumed by 02-servers via terraform_remote_state
# ==============================================================================

output "compartment_ocid" {
  description = "Compartment OCID for 02-servers to provision into."
  value       = var.compartment_ocid
}

output "vcn_id" {
  description = "VCN OCID for NSG and subnet lookups in 02-servers."
  value       = oci_core_vcn.ad_vcn.id
}

output "vm_subnet_ocid" {
  description = "OCID of vm-subnet for client instance placement."
  value       = oci_core_subnet.vm_subnet.id
}

output "administrator_password" {
  description = "Built-in Administrator account password — SSH/RDP into DC."
  value       = random_password.administrator_password.result
  sensitive   = true
}

output "admin_domain_password" {
  description = "Password for the Admin domain admin account."
  value       = random_password.admin_domain_password.result
  sensitive   = true
}

output "ssh_public_key" {
  description = "SSH public key for authorizing on Linux client instances."
  value       = tls_private_key.ssh.public_key_openssh
}

output "dc_private_ip" {
  description = "Private IP of the AD DC — used as the bastion session target."
  value       = module.windows_ad.dns_server
}

output "dc_public_ip" {
  description = "Public IP of the DC — only set when assign_public_ip = true."
  value       = module.windows_ad.dc_public_ip
}

output "bastion_id" {
  description = "OCID of the OCI Bastion for creating RDP sessions."
  value       = oci_bastion_bastion.ad_bastion.id
}

output "dns_zone" {
  description = "AD DNS zone — used by get_password.sh to display fully-qualified usernames."
  value       = var.dns_zone
}

output "windows_local_admin_password" {
  description = "Local admin password for the Windows client instance — RDP fallback."
  value       = random_password.windows_local_admin_password.result
  sensitive   = true
}

output "jsmith_password" {
  value     = random_password.jsmith_password.result
  sensitive = true
}

output "edavis_password" {
  value     = random_password.edavis_password.result
  sensitive = true
}

output "rpatel_password" {
  value     = random_password.rpatel_password.result
  sensitive = true
}

output "akumar_password" {
  value     = random_password.akumar_password.result
  sensitive = true
}
