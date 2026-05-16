# ==============================================================================
# OCI Compartment
# ==============================================================================

variable "compartment_ocid" {
  description = "OCID of the OCI compartment to deploy all resources into."
  type        = string
}

variable "tenancy_ocid" {
  description = "OCID of the root tenancy."
  type        = string
}

# ==============================================================================
# Active Directory Naming Inputs
# ==============================================================================

variable "dns_zone" {
  description = "AD DNS zone / domain (e.g., mcloud.mikecloud.com)"
  type        = string
  default     = "mcloud.mikecloud.com"
}

variable "realm" {
  description = "Kerberos realm (e.g., MCLOUD.MIKECLOUD.COM)"
  type        = string
  default     = "MCLOUD.MIKECLOUD.COM"
}

variable "netbios" {
  description = "NetBIOS short domain name (e.g., MCLOUD)"
  type        = string
  default     = "MCLOUD"
}

variable "vcn_name" {
  description = "Display name for the VCN."
  type        = string
  default     = "windows-ad-vcn"
}
