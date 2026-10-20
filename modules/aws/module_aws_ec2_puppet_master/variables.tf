variable "vpc_id" {
  type        = string
  description = "VPC ID for the Puppet master security group"
}

variable "subnet_id" {
  type        = string
  description = "Subnet to launch the Puppet master in"
}

variable "key_name" {
  type        = string
  description = "Name of an existing EC2 key pair"
}

variable "web_security_group_id" {
  type        = string
  description = "Security group ID of the web nodes allowed to reach the Puppet master on 8140"
}

variable "puppet_master_fqdn" {
  type        = string
  description = "FQDN of the Puppet master"
}

variable "puppet_autosign_secret" {
  type        = string
  description = "Shared secret used for Puppet certificate autosigning"
  sensitive   = true
}
