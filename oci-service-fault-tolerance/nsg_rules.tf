# SSH
resource "oci_core_network_security_group_security_rule" "ssh_ingress" {
  network_security_group_id = oci_core_network_security_group.ha_nsg.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP
  source                     = "0.0.0.0/0"

  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }
}

# DRBD
resource "oci_core_network_security_group_security_rule" "drbd_ingress" {
  network_security_group_id = oci_core_network_security_group.ha_nsg.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP
  source                     = "0.0.0.0/0"

  tcp_options {
    destination_port_range {
      min = 7789
      max = 7789
    }
  }
}

# Corosync
resource "oci_core_network_security_group_security_rule" "corosync_ingress" {
  network_security_group_id = oci_core_network_security_group.ha_nsg.id
  direction                 = "INGRESS"
  protocol                  = "17" # UDP
  source                     = "0.0.0.0/0"

  udp_options {
    destination_port_range {
      min = 5404
      max = 5405
    }
  }
}

# Service ports (HTTP example, optional)
resource "oci_core_network_security_group_security_rule" "service_http" {
  network_security_group_id = oci_core_network_security_group.ha_nsg.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                     = "0.0.0.0/0"

  tcp_options {
    destination_port_range {
      min = 80
      max = 80
    }
  }
}

# General routing inside
resource "oci_core_network_security_group_security_rule" "egress_all" {
  network_security_group_id = oci_core_network_security_group.ha_nsg.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
}
