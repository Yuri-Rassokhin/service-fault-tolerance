output "node1_private_ip" {
  value = oci_core_instance.node1.private_ip
}

output "node2_private_ip" {
  value = oci_core_instance.node2.private_ip
}

output "block_volume_ids" {
  value = [
    oci_core_volume.drbd_volume_1.id,
    oci_core_volume.drbd_volume_2.id
  ]
}

output "selected_image" {
  value = {
    name = local.image_name
    ocid = local.image_ocid
  }
}

output "oracle_linux_debug" {
  value = local.oracle_linux_ranked
}

