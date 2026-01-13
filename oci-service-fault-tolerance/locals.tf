locals {
  region = var.cross_ad_fault_tolerance ? var.region_multi_ad : var.region_single_ad
  ad_names = data.oci_identity_availability_domains.ads.availability_domains[*].name
  ad_primary = local.ad_names[0]
  ad_secondary = local.ad_names[length(local.ad_names) - 1]

  # Mapping: Effective VPU (GUI) -> True OCI VPU
  effective_to_true_vpu = {
    0  = 0
    10 = 20
    20 = 50
    30 = 70
    40 = 90
    50 = 120
  }
  true_block_volume_vpu = lookup(local.effective_to_true_vpu, var.block_volume_vpu, 20)
}

