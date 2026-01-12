locals {
  ad_names = data.oci_identity_availability_domains.ads.availability_domains[*].name
  ad_count = length(local.ad_names)

  # Guard: multi-AD requires >= 2 ADs
  _require_multi_ad_region = (
    var.cross_ad_fault_tolerance && local.ad_count < 2
  ) ? error(
    "cross_ad_fault_tolerance=true requires a region with at least 2 Availability Domains"
  ) : true

  # Placement
  ad_primary = local.ad_names[0]

  ad_secondary = (
    var.cross_ad_fault_tolerance
    ? local.ad_names[1]
    : local.ad_names[0]
  )

  # Region resolution
  region = var.cross_ad_fault_tolerance ? var.region_multi_ad : var.region_single_ad

  # VCN region consistency (parsed from OCID)
  region_from_vcn = regex("oc1\\.([a-z0-9-]+)\\.", var.vcn_ocid)[0]

  _validate_vcn_region = local.region_from_vcn == local.region
    ? true
    : error("VCN ${var.vcn_ocid} does not belong to region ${local.region}")
}

