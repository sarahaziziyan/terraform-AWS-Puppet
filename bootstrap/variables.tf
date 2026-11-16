variable "region" {
  type        = string
  description = "AWS region of the main stack. The SSM parameter must live in the same region as the instances that read it"
  default     = "ap-southeast-1"
}

variable "autosign_secret_parameter_name" {
  type        = string
  description = "Name of the SSM parameter that holds the Puppet autosign secret"
  default     = "/puppet/autosign-secret"
}

variable "autosign_secret_version" {
  type        = number
  description = "Increase by one and apply to generate a new autosign secret (rotation)"
  default     = 1
}

variable "puppet_master_role_name" {
  type        = string
  description = "Name of the Puppet master's IAM role and instance profile"
  default     = "puppet-master-autosign-reader"
}

variable "web_node_role_name" {
  type        = string
  description = "Name of the web nodes' IAM role and instance profile"
  default     = "web-node-autosign-reader"
}

variable "terraform_user_name" {
  type        = string
  description = "IAM user that applies the main stack. It is allowed to attach the two roles to EC2 instances, nothing more"
  default     = "terraform-user"
}
