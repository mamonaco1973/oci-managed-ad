# ==============================================================================
# OCI Bastion Service
# ------------------------------------------------------------------------------
# Purpose:
#   - Provides managed RDP access to the private AD DC instance without
#     exposing it to the public internet.
#   - Port-forwarding sessions require no OCI agent on the target instance.
#
# Usage (after apply):
#   See connect.sh for the OCI CLI + SSH tunnel commands to reach the DC via RDP.
# ==============================================================================

resource "oci_bastion_bastion" "ad_bastion" {
  bastion_type     = "STANDARD"
  compartment_id   = var.compartment_ocid
  # Targets the private subnet where the DC lives
  target_subnet_id = oci_core_subnet.ad_subnet.id
  name             = "windows-ad-bastion"

  # Restrict to your IP in production
  client_cidr_block_allow_list = ["0.0.0.0/0"]
}
