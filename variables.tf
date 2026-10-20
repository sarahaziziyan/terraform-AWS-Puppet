# General
variable "region" {
  type = string
}

variable "key_name" {
  type        = string
  description = "Name of an existing EC2 key pair"
}

# Network
variable "vpc_id" {
  type        = string
  description = "VPC ID for the ALB and ASG"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnet IDs for the ALB and ASG (at least two AZs)"
}

variable "subnet_id" {
  type        = string
  description = "Subnet to launch the instance in"
}

# Puppet
variable "puppet_autosign_secret" {
  type      = string
  sensitive = true
}

# Website
variable "site_repo_url" {
  type        = string
  description = "Public Git repository containing the website (index.html at the root)"
}

variable "site_repo_branch" {
  type = string
}

# Auto Scaling Group
variable "asg_min_size" {
  type        = number
  description = "Minimum number of instances in ASG"
}

variable "asg_desired_capacity" {
  type        = number
  description = "Desired number of instances in ASG"
}

variable "asg_max_size" {
  type        = number
  description = "Maximum number of instances in ASG"
}

variable "cpu_threshold" {
  type        = number
  description = "CPU threshold for scaling policy"
}