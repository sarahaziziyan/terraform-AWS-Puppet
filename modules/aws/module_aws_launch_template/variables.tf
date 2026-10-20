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

variable "puppet_autosign_secret" {
  type        = string
  description = "Shared secret used for Puppet certificate autosigning"
  sensitive   = true
}
