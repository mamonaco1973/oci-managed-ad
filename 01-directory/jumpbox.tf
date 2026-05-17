# ==============================================================================
# Windows Jump Box
# ------------------------------------------------------------------------------
# Public-subnet Windows Server 2022 instance for RDP access into the private
# AD subnet. Use this to reach the DC when bastion SSH is unavailable.
# ==============================================================================

/*
data "oci_core_images" "windows_jumpbox" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Windows"
  operating_system_version = "Server 2022 Standard"
  shape                    = "VM.Standard.E4.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

data "oci_identity_availability_domains" "jumpbox_ads" {
  compartment_id = var.compartment_ocid
}

resource "oci_core_instance" "jumpbox" {
  availability_domain = data.oci_identity_availability_domains.jumpbox_ads.availability_domains[0].name
  compartment_id      = var.compartment_ocid
  shape               = "VM.Standard.E4.Flex"
  display_name        = "windows-jumpbox"

  shape_config {
    ocpus         = 1
    memory_in_gbs = 8
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.windows_jumpbox.images[0].id
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.vm_subnet.id
    assign_public_ip = true
  }

  metadata = {
    user_data = base64encode(templatefile("${path.module}/scripts/jumpbox-userdata.ps1.template", {
      JUMPBOX_LOCAL_ADMIN_PASS = random_password.windows_local_admin_password.result
    }))
  }
}

output "jumpbox_public_ip" {
  description = "Public IP of the Windows jump box - RDP directly to this address."
  value       = oci_core_instance.jumpbox.public_ip
}
*/
