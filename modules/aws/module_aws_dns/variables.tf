variable "vpc_id" {
  type        = string
  description = "VPC ID the private hosted zone is associated with"
}

variable "puppet_master_fqdn" {
  type        = string
  description = "FQDN of the Puppet master record"
}

variable "puppet_master_private_ip" {
  type        = string
  description = "Private IP address the Puppet master record points to"
}
