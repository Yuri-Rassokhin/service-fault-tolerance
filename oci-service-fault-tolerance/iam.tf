resource "random_id" "name_suffix" {
  byte_length = 3
}

locals {
  # базовое имя берём из service_hostname, но чистим и режем длину
  base_name = substr(
    lower(replace(var.service_hostname, "/[^a-zA-Z0-9-]/", "-")),
    0,
    20
  )

  dg_name     = "${local.base_name}-${random_id.name_suffix.hex}-dg"
  policy_name = "${local.base_name}-${random_id.name_suffix.hex}-policy"
}

resource "oci_identity_dynamic_group" "ha_nodes" {
  compartment_id = var.tenancy_ocid
  name           = local.dg_name
  description    = "HA nodes dynamic group for floating secondary private IP failover"

  # ВАЖНО: ограничиваем группу ТОЛЬКО двумя инстансами этого стека
  matching_rule = "ANY {instance.id = '${oci_core_instance.node1.id}', instance.id = '${oci_core_instance.node2.id}'}"
}

resource "oci_identity_policy" "ha_nodes_policy" {
  compartment_id = var.compartment_ocid
  name           = local.policy_name
  description    = "Allow HA nodes to manage secondary private IP (floating IP) failover"

  statements = [
    "Allow dynamic-group ${oci_identity_dynamic_group.ha_nodes.name} to manage private-ips in compartment id ${var.compartment_ocid}",
    "Allow dynamic-group ${oci_identity_dynamic_group.ha_nodes.name} to read vnics in compartment id ${var.compartment_ocid}",
    "Allow dynamic-group ${oci_identity_dynamic_group.ha_nodes.name} to read vnic-attachments in compartment id ${var.compartment_ocid}",
  ]
}

