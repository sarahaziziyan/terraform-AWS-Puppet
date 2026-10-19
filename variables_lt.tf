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

variable "subnet_id" {
  type        = string
  description = "Subnet to launch the instance in"
  default     = "subnet-088e08ec462af6a3e"
}
