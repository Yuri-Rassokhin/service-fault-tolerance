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

  used_ips = [
    for ip in data.oci_core_private_ips.used.private_ips :
    ip.ip_address
  ]

  all_ips = [
    for i in range(4, 250) :
    cidrhost(local.subnet_cidr, i)
  ]

  service_ip = one([
    for ip in local.all_ips :
    ip if !contains(local.used_ips, ip)
  ])
}

output "service_ip" {
  value = local.service_ip
}

