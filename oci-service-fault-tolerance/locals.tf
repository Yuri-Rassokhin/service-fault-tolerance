locals {
  # Placement policy
  ad_primary   = local.ad_names[0]
  ad_secondary = var.cross_ad_fault_tolerance ? local.ad_names[1] : local.ad_names[0]

  # Location
  region = var.cross_ad_fault_tolerance ? var.region_multi_ad : var.region_single_ad

  # Network consistency
  vcn_region_ok = data.oci_core_vcn.selected.region == var.region
  subnet_in_vcn = data.oci_core_subnet.selected.vcn_id == var.vcn_ocid
}

