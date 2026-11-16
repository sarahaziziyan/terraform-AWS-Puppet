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
# Created by the admin-applied bootstrap/ config. The defaults match its defaults.
variable "autosign_secret_parameter_name" {
  type        = string
  description = "SSM SecureString parameter holding the Puppet autosign secret (output of bootstrap/)"
  default     = "/puppet/autosign-secret"
}

variable "puppet_master_instance_profile_name" {
  type        = string
  description = "Instance profile for the Puppet master (output of bootstrap/)"
  default     = "puppet-master-autosign-reader"
}

variable "web_node_instance_profile_name" {
  type        = string
  description = "Instance profile for the web nodes (output of bootstrap/)"
  default     = "web-node-autosign-reader"
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
  description = "Number of instances when the ASG is first created. Ignored afterwards: the scaling policy owns the running count"
}

variable "asg_max_size" {
  type        = number
  description = "Maximum number of instances in ASG"
}

variable "cpu_threshold" {
  type        = number
  description = "CPU threshold for scaling policy"
}