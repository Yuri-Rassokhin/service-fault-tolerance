locals {
  region = var.cross_ad_fault_tolerance ? var.region_multi_ad : var.region_single_ad
  ad_names = data.oci_identity_availability_domains.ads.availability_domains[*].name
  ad_primary = element(local.ad_names, 0)
  ad_secondary = element(local.ad_names, -1)
}

