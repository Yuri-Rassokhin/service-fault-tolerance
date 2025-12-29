########################################
# Random suffix to avoid name collisions
########################################
resource "random_id" "name_suffix" {
  byte_length = 3
}

########################################
# Deterministic but unique names
########################################
locals {
  base_name = substr(
    lower(replace(var.service_hostname, "/[^a-zA-Z0-9-]/", "-")),
    0,
    20
  )

  dg_name     = "${local.base_name}-${random_id.name_suffix.hex}-dg"
  policy_name = "${local.base_name}-${random_id.name_suffix.hex}-policy"
}

########################################
# Dynamic Group (TENANCY scope)
########################################
resource "oci_identity_dynamic_group" "ha_nodes" {
  compartment_id = var.tenancy_ocid
  name           = local.dg_name
  description    = "HA nodes dynamic group for floating private IP failover"

  matching_rule = "ANY {instance.id = '${oci_core_instance.node1.id}', instance.id = '${oci_core_instance.node2.id}'}"
}

########################################
# IAM Policy (COMPARTMENT scope)
########################################
resource "oci_identity_policy" "ha_nodes_policy" {
  compartment_id = var.compartment_ocid
  name           = local.policy_name
  description    = "Allow HA nodes to manage their configurations"

  statements = [
    "Allow dynamic-group ${oci_identity_dynamic_group.ha_nodes.name} to manage virtual-network-family in compartment id ${var.compartment_ocid}",
    "Allow dynamic-group ${oci_identity_dynamic_group.ha_nodes.name} to manage instance-family in compartment id ${var.compartment_ocid}",
    "Allow dynamic-group ${oci_identity_dynamic_group.ha_nodes.name} to manage volume-attachments in compartment id ${var.compartment_ocid}",
    "Allow dynamic-group ${oci_identity_dynamic_group.ha_nodes.name} to manage volumes in compartment id ${var.compartment_ocid}"
  ]
}
