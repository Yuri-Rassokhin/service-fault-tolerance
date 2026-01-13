output "service_hostname" {
  value = "${var.service_hostname}.${trim(local.resilient_zone_name, ".")}"
}

output "service_ip" {
  value = local.service_ip
}

output "resilient_mount_point" {
  value = var.mount_point
}

output "region" {
  value = local.region
}

output "node1_private_ip" {
  value = oci_core_instance.node1.private_ip
}

output "node1_availability_domain" {
  value = local.ad_primary
}

output "node1_volume" {
  value = oci_core_volume.drbd_volume_1.id
}

output "node1_volume_size" {
  value = var.block_volume_size_gbs
}

output "node1_volume_true_vpu" {
  value = local.true_block_volume_vpu
}

output "node2_private_ip" {
  value = oci_core_instance.node2.private_ip
}

output "node2_availability_domain" {
  value = local.ad_secondary
}

output "node2_volume" {
  value = oci_core_volume.drbd_volume_2.id
}

output "node2_volume_size" {
  value = var.block_volume_size_gbs
}

output "node2_volume_true_vpu" {
  value = local.true_block_volume_vpu
}

output "operating_system_name" {
  value = local.image_name
}

output "operating_system_image" {
  value = local.image_ocid
}

output "oracle_linux_debug" {
  value = local.oracle_linux_ranked
}

