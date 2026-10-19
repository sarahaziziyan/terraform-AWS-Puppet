variable "region" {
  default = "ap-southeast-1"
}

variable "admin_ssh_cidr" {
  type        = string
  description = "CIDR allowed to SSH to the Puppet master (your public IP, e.g. 203.0.113.10/32)"
  default     = "103.171.42.9/32"
}

variable "puppet_autosign_secret" {
  type      = string
  sensitive = true
}

variable "site_repo" {
  type = string
}

variable "site_repo_branch" {
  type = string
}

