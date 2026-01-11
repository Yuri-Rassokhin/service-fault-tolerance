locals {
  # Placement
  ad_primary   = local.ad_names[0]
  ad_secondary = var.cross_ad_fault_tolerance ? local.ad_names[1] : local.ad_names[0]

  # Region normalization
  region = var.cross_ad_fault_tolerance ? var.region_multi_ad : var.region_single_ad

  # Region validation
  region_from_vcn = regex("oc1\\.([a-z0-9-]+)\\.", var.vcn_ocid)[0]
  vcn_region_ok   = local.region_from_vcn == local.region

  # Network consistency
  subnet_in_vcn = data.oci_core_subnet.selected.vcn_id == var.vcn_ocid

  # Guards
  _validate_region = (var.cross_ad_fault_tolerance && var.region_multi_ad == null) ? error("cross_ad_fault_tolerance=true requires region_multi_ad") : (!var.cross_ad_fault_tolerance && var.region_single_ad == null) ? error("cross_ad_fault_tolerance=false requires region_single_ad") : true

  _validate_vcn_region = local.vcn_region_ok ? true : error("VCN ${var.vcn_ocid} does not belong to region ${local.region}")

  _validate_subnet_vcn = local.subnet_in_vcn ? true : error("Subnet ${var.subnet_ocid} does not belong to VCN ${var.vcn_ocid}")

}

