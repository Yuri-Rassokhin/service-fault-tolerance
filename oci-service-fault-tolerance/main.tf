
data "oci_core_vcn" "selected" {
  vcn_id = var.vcn_ocid
}

data "oci_core_subnet" "selected" {
  subnet_id = var.subnet_ocid
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
}

data "oci_core_images" "oracle_linux_all" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Oracle Linux"
  operating_system_version = null
  shape                    = var.shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

locals {
  oracle_linux_filtered = [
    for img in data.oci_core_images.oracle_linux_all.images :
    img
    if (
      can(regex("^Oracle-Linux-[0-9]+\\.", img.display_name)) &&
      !can(regex("GPU", img.display_name)) &&
      !can(regex("aarch", img.display_name)) &&
      !can(regex("Developer", img.display_name)) &&
      !can(regex("Minimal", img.display_name))
    )
  ]
}

locals {
  oracle_linux_ranked = [
    for img in local.oracle_linux_filtered : {
      img   = img
      major = try(
        tonumber(regex("^Oracle-Linux-([0-9]+)", img.display_name)[0]),
        null
      )
    }
  ]
}

locals {
  oracle_linux_latest_major = max([
    for r in local.oracle_linux_ranked : r.major
    if r.major != null
  ]...)
}

locals {
  oracle_linux_latest = [
    for r in local.oracle_linux_ranked : r.img
    if r.major == local.oracle_linux_latest_major
  ][0]
}

locals {
  image_ocid = local.oracle_linux_latest.id
  image_name = local.oracle_linux_latest.display_name
}

resource "oci_core_volume" "drbd_volume_1" {
  availability_domain = local.ad_primary
  compartment_id      = var.compartment_ocid
  size_in_gbs         = var.block_volume_size_gbs
  display_name        = "drbd-volume-1"
}

resource "oci_core_volume" "drbd_volume_2" {
  availability_domain = local.ad_secondary
  compartment_id      = var.compartment_ocid
  size_in_gbs         = var.block_volume_size_gbs
  display_name        = "drbd-volume-2"
}

resource "oci_core_instance" "node1" {
  availability_domain = local.ad_primary
  compartment_id      = var.compartment_ocid
  shape               = var.shape
  display_name        = "ha-node-1"

  shape_config {
    ocpus         = var.ocpus
    memory_in_gbs = var.memory_gbs
  }

  source_details {
    source_type = "image"
    source_id   = local.image_ocid
  }

  create_vnic_details {
    subnet_id = var.subnet_ocid
    nsg_ids = [
      oci_core_network_security_group.ha_nsg.id
    ]
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(templatefile(
      "${path.module}/cloud_init.yaml.tpl",
      {
        node_name           = "ha-node-1"
        peer_node_name      = "ha-node-2"
        region              = local.region
        subnet_ocid         = var.subnet_ocid
        fs_type             = var.fs_type
        mount_point         = var.mount_point
        service_hostname    = var.service_hostname
        nsg_ocid            = oci_core_network_security_group.ha_nsg.id
        volume_ocid         = oci_core_volume.drbd_volume_1.id
	dns_zone_ocid       = local.resilient_zone_ocid
	dns_zone_name       = local.resilient_zone_name
	dns_view_ocid       = local.dns_view_ocid
	service_ip          = local.service_ip
      }
    ))
  }
}

resource "oci_core_instance" "node2" {
  availability_domain = local.ad_secondary
  compartment_id      = var.compartment_ocid
  shape               = var.shape
  display_name        = "ha-node-2"

  shape_config {
    ocpus         = var.ocpus
    memory_in_gbs = var.memory_gbs
  }

  source_details {
    source_type = "image"
    source_id   = local.image_ocid
  }

  create_vnic_details {
    subnet_id = var.subnet_ocid
    nsg_ids = [
      oci_core_network_security_group.ha_nsg.id
    ]
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(templatefile(
      "${path.module}/cloud_init.yaml.tpl",
      {
        node_name           = "ha-node-2"
        peer_node_name      = "ha-node-1"
        region              = local.region
        subnet_ocid         = var.subnet_ocid
        fs_type             = var.fs_type
        mount_point         = var.mount_point
        service_hostname    = var.service_hostname
        nsg_ocid            = oci_core_network_security_group.ha_nsg.id
        volume_ocid         = oci_core_volume.drbd_volume_2.id
        dns_zone_ocid       = local.resilient_zone_ocid
        dns_zone_name       = local.resilient_zone_name
        dns_view_ocid       = local.dns_view_ocid
        service_ip          = local.service_ip
      }
    ))
  }
}

resource "oci_core_volume_attachment" "attach1" {
  instance_id     = oci_core_instance.node1.id
  volume_id       = oci_core_volume.drbd_volume_1.id
  attachment_type = "iscsi"
  device          = "/dev/oracleoci/oraclevdb"
}

resource "oci_core_volume_attachment" "attach2" {
  instance_id     = oci_core_instance.node2.id
  volume_id       = oci_core_volume.drbd_volume_2.id
  attachment_type = "iscsi"
  device          = "/dev/oracleoci/oraclevdb"
}

