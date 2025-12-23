locals {
  dg_name     = "ha-cluster-nodes"
  policy_name = "ha-cluster-nodes-policy"
}

resource "oci_identity_dynamic_group" "ha_nodes" {
  compartment_id = var.tenancy_ocid
  name           = local.dg_name
  description    = "Instances allowed to move floating secondary private IP between HA nodes"

  # Simple: restrict to compartment where HA instances will be living
  # NOTE: this Dynamic Group will involve ALL instance of this compartment - this can be fine-tuned separately
  matching_rule  = "ANY {instance.compartment.id = '${var.compartment_ocid}'}"
}

resource "oci_identity_policy" "ha_nodes_policy" {
  compartment_id = var.compartment_ocid
  name           = local.policy_name
  description    = "Allow HA nodes to manage secondary private IP (floating IP) failover"

  statements = [
    # Crucial: allow assignment/reassignment of a private IP, and its migration across VNICs
    "Allow dynamic-group ${oci_identity_dynamic_group.ha_nodes.name} to manage private-ips in compartment id ${var.compartment_ocid}",

    # To be able to check attachment
    "Allow dynamic-group ${oci_identity_dynamic_group.ha_nodes.name} to read vnics in compartment id ${var.compartment_ocid}",
    "Allow dynamic-group ${oci_identity_dynamic_group.ha_nodes.name} to read vnic-attachments in compartment id ${var.compartment_ocid}",
  ]
}
