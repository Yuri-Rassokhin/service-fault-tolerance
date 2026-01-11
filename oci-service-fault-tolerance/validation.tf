resource "null_resource" "validate_network" {
  lifecycle {
    precondition {
      condition     = local.vcn_region_ok
      error_message = "Selected VCN does not belong to region ${var.region}"
    }

    precondition {
      condition     = local.subnet_in_vcn
      error_message = "Subnet does not belong to selected VCN"
    }
  }
}

resource "null_resource" "validate_ad_policy" {
  lifecycle {
    precondition {
      condition = (
        var.cross_ad_fault_tolerance == false ||
        length(local.ad_names) >= 2
      )
      error_message = "Cross-AD mode requires region with at least 2 Availability Domains"
    }
  }
}

