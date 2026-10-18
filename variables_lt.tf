variable "key_name" {
  type        = string
  description = "Name of an existing EC2 key pair"
  default     = "ec2-keypair"
}

variable "site_repo_url" {
  type        = string
  description = "Public Git repository containing the website (index.html at the root)"
  default     = "https://github.com/sarahaziziyan/adhd-helper.git"
}

variable "site_repo_branch" {
  type        = string
  description = "Branch of the website repository to deploy"
  default     = "main"
}

variable "subnet_id" {
  type        = string
  description = "Subnet to launch the instance in"
}
