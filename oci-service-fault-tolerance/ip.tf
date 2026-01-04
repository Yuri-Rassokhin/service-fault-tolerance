############################
# Compute deterministic SERVICE_IP
############################

data "oci_core_subnet" "target" {
  subnet_id = var.subnet_ocid
}

data "oci_core_private_ips" "used" {
  subnet_id = var.subnet_ocid
}

locals {
  subnet_cidr = data.oci_core_subnet.target.cidr_block

  used_ips = toset([
    for ip in data.oci_core_private_ips.used.private_ips :
    ip.ip_address
  ])

  candidate_ips = [
    for i in range(4, 250) :
    cidrhost(local.subnet_cidr, i)
    if !contains(local.used_ips, cidrhost(local.subnet_cidr, i))
  ]

  service_ip = local.candidate_ips[0]
}

resource "oci_core_private_ip" "service_ip" {
  subnet_id  = var.subnet_ocid
  vnic_id    = var.primary_vnic_ocid
  ip_address = local.service_ip
}

output "service_ip" {
  value = local.service_ip
}

output "service_ip_ocid" {
  value = oci_core_private_ip.service_ip.id
}
