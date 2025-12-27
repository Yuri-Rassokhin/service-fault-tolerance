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
  # Clean + limit base name
  base_name = substr(
    lower(replace(var.service_hostname, "/[^a-zA-Z0-9-]/", "-")),
    0,
    20
  )

  dg_name     = "${local.base_name}-${random_id.name_suffix.hex}-dg"
  policy_name = "${local.base_name}-${random_id.name_suffix.hex}-policy"
}

########################################
# Dynamic Group (TENANCY level!)
########################################
resource "oci_identity_dynamic_group" "ha_nodes" {
  compartment_id = var.tenancy_ocid
  name           = local.dg_name
  description    = "HA nodes dynamic group for floating private IP failover"

  # STRICT scoping: only instances created by this stack
  matching_rule = "ANY {
    instance.id = '${oci_core_instance.node1.id}',
    instance.id = '${oci_core_instance.node2.id}'
  }"
}

########################################
# IAM Policy (COMPARTMENT level)
########################################
resource "oci_identity_policy" "ha_nodes_policy" {
  compartment_id = var.compartment_ocid
  name           = local.policy_name
  description    = "Allow HA nodes to manage networking for floating IP failover"

  statements = [
    # Required for:
    # - subnet get
    # - private-ip list / delete
    # - vnic assign-private-ip
    "Allow dynamic-group ${oci_identity_dynamic_group.ha_nodes.name} to manage virtual-network-family in compartment id ${var.compartment_ocid}",

    # Optional but useful (metadata, introspection, safety)
    "Allow dynamic-group ${oci_identity_dynamic_group.ha_nodes.name} to read instance-family in compartment id ${var.compartment_ocid}",
  ]
}
