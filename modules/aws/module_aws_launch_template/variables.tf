variable "key_name" {
  type        = string
  description = "Name of an existing EC2 key pair"
}

variable "security_group_ids" {
  type        = list(string)
  description = "Security group IDs attached to the instances"
}

variable "site_repo_url" {
  type        = string
  description = "Public Git repository containing the website (index.html at the root)"
}

variable "site_repo_branch" {
  type        = string
  description = "Branch of the website repository to deploy"
}

variable "puppet_master_fqdn" {
  type        = string
  description = "FQDN of the Puppet master"
}

variable "autosign_secret_parameter_name" {
  type        = string
  description = "Name of the SSM SecureString parameter holding the Puppet autosign secret (created by bootstrap/)"
}

variable "instance_profile_name" {
  type        = string
  description = "Instance profile that lets the web nodes read the autosign secret (created by bootstrap/)"
}
