### REQUIRED ###

variable "compartment_ocid" {
  description = "Compartment where fault-tolerant cluster will be deployed"
  type        = string
  validation {
    condition = length(trimspace(var.compartment_ocid)) > 0
    error_message = "Compartment OCID is required"
  }
}

variable "vcn_ocid" {
  description = "VCN where fault-tolerant cluster will be deployed"
  type        = string
  validation {
    condition = length(trimspace(var.vcn_ocid)) > 0
    error_message = "VCN OCID is required"
  }
}

variable "subnet_ocid" {
  description = "Subnet where fault-tolerant cluster will be deployed"
  type        = string
  validation {
    condition = length(trimspace(var.subnet_ocid)) > 0
    error_message = "Subnet OCID is required"
  }
}

variable "ssh_public_key" {
  description = "SSH public key to access fault tolerant instance"
  type        = string
  validation {
    condition = length(trimspace(var.ssh_public_key)) > 0
    error_message = "SSH public key is required"
  }
}

variable "region" {
  type        = string
  validation {
    condition = length(trimspace(var.region)) > 0
    error_message = "OCI region is required"
  }
}

### COMPUTE ###

variable "shape" {
  type    = string
  default = "VM.Standard.E5.Flex"
}

variable "ocpus" {
  type    = number
  default = 2
}

variable "memory_gbs" {
  type    = number
  default = 16
}

### STORAGE / HA ###

variable "block_volume_size_gbs" {
  type    = number
  default = 200
}

variable "mount_point" {
  type    = string
  default = "/resilient"
}

variable "fs_type" {
  type    = string
  default = "xfs"
}

variable "service_hostname" {
  type    = string
  default = "fault-tolerant-service"
}

variable "ha_cluster_password" {
  type = string
  default = "MyStrongPassword"
}

variable "tenancy_ocid" {
  type = string
  description = "Tenancy OCID, required for dynamic group and network operations"
}
