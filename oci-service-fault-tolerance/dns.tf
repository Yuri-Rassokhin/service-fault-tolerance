############################
# DNS Resolver (existing VCN resolver)
############################

data "oci_dns_resolvers" "vcn_resolvers" {
  compartment_id = var.compartment_ocid
  scope          = "PRIVATE"
}

locals {
  vcn_resolver_id = one([
    for r in data.oci_dns_resolvers.vcn_resolvers.resolvers :
    r.id if r.attached_vcn_id == var.vcn_ocid
  ])
}

############################
# Private DNS View (managed by this stack)
############################

resource "oci_dns_view" "resilient" {
  compartment_id = var.compartment_ocid
  scope          = "PRIVATE"
  display_name   = "resilient-view"

  freeform_tags = {
    managed-by = "terraform"
    stack      = "ha-drbd"
  }
}

############################
# Attach View to VCN Resolver
############################

resource "oci_dns_resolver" "attach_view" {
  resolver_id = local.vcn_resolver_id

  attached_views {
    view_id = oci_dns_view.resilient.id
  }
}

############################
# Discover existing private zones
############################

data "oci_dns_zones" "private_zones" {
  compartment_id = var.compartment_ocid
  scope          = "PRIVATE"
}

locals {
  resilient_zone_name = "resilient.oci."

  existing_resilient_zone = try(
    one([
      for z in data.oci_dns_zones.private_zones.zones :
      z if z.name == local.resilient_zone_name
    ]),
    null
  )
}

############################
# Private DNS Zone (create only if absent)
############################

resource "oci_dns_zone" "resilient" {
  count          = local.existing_resilient_zone == null ? 1 : 0

  compartment_id = var.compartment_ocid
  name           = local.resilient_zone_name
  zone_type      = "PRIMARY"
  scope          = "PRIVATE"
  view_id        = oci_dns_view.resilient.id

  freeform_tags = {
    managed-by = "terraform"
    stack      = "ha-drbd"
  }
}

############################
# Effective zone identity (for HA / agents)
############################

locals {
  resilient_zone_ocid = local.existing_resilient_zone != null
    ? local.existing_resilient_zone.id
    : oci_dns_zone.resilient[0].id
}

############################
# Outputs to HA stack
############################

output "dns_zone_name" {
  value = local.resilient_zone_name
}

output "dns_zone_ocid" {
  value = local.resilient_zone_ocid
}
