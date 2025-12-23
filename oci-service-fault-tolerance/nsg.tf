resource "oci_core_network_security_group" "ha_nsg" {
  compartment_id = var.compartment_ocid
  vcn_id         = var.vcn_ocid
  display_name   = "ha-fault-tolerance-nsg"
}
