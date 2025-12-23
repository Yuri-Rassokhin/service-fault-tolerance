############################
# Availability Domain
############################

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
}

locals {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
}

############################
# Rocky Linux 9 Image
############################

data "oci_core_images" "oracle_linux_latest" {
  compartment_id   = var.compartment_ocid
  operating_system = "Oracle Linux"
  shape            = var.shape

  # Get Oracle Linux flavours only
  filter {
    name   = "display_name"
    regex  = true
    values = [
      "^Oracle-Linux-[0-9]+\\.[0-9]+-[0-9]{4}\\.[0-9]{2}\\.[0-9]{2}-[0-9]+$"
    ]
  }

  # Filter out anything but 'Oracle Linux' for x86_64
  # NOTE: The filter automatially sorts results from the newest to oldest so we always get the latest release
  filter {
    name   = "display_name"
    regex  = true
    negate = true
    values = [
      ".*GPU.*",
      ".*aarch64.*",
      ".*Developer.*",
      ".*Minimal.*",
      ".*Autonomous.*"
    ]
  }
}

locals {
  image_ocid = data.oci_core_images.oracle_linux_latest.images[0].id
  image_name = data.oci_core_images.oracle_linux_latest.images[0].display_name
}

############################
# Block Volumes
############################

resource "oci_core_volume" "drbd_volume_1" {
  availability_domain = local.availability_domain
  compartment_id      = var.compartment_ocid
  size_in_gbs         = var.block_volume_size_gbs
  display_name        = "drbd-volume-1"
}

resource "oci_core_volume" "drbd_volume_2" {
  availability_domain = local.availability_domain
  compartment_id      = var.compartment_ocid
  size_in_gbs         = var.block_volume_size_gbs
  display_name        = "drbd-volume-2"
}

############################
# Compute Instance: Node 1
############################

resource "oci_core_instance" "node1" {
  availability_domain = local.availability_domain
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
        region              = var.region
        subnet_ocid         = var.subnet_ocid
        fs_type             = var.fs_type
        mount_point         = var.mount_point
        service_hostname    = var.service_hostname
        nsg_ocid            = oci_core_network_security_group.ha_nsg.id
        volume_ocid         = oci_core_volume.drbd_volume_1.id
      }
    ))
  }
}

############################
# Compute Instance: Node 2
############################

resource "oci_core_instance" "node2" {
  availability_domain = local.availability_domain
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
        region              = var.region
        subnet_ocid         = var.subnet_ocid
        fs_type             = var.fs_type
        mount_point         = var.mount_point
        service_hostname    = var.service_hostname
        nsg_ocid            = oci_core_network_security_group.ha_nsg.id
        volume_ocid         = oci_core_volume.drbd_volume_2.id
      }
    ))
  }
}

############################
# Volume Attachments
############################

resource "oci_core_volume_attachment" "attach1" {
  instance_id     = oci_core_instance.node1.id
  volume_id       = oci_core_volume.drbd_volume_1.id
  attachment_type = "paravirtualized"
}

resource "oci_core_volume_attachment" "attach2" {
  instance_id     = oci_core_instance.node2.id
  volume_id       = oci_core_volume.drbd_volume_2.id
  attachment_type = "paravirtualized"
}
