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
  description = "Minimum number of web servers in working hours. On an existing ASG it takes effect at the next schedule start, not on apply (ADR 0026)"
}

variable "asg_desired_capacity" {
  type        = number
  description = "Number of instances when the ASG is first created. Ignored afterwards: the scaling policy owns the running count"
}

variable "asg_max_size" {
  type        = number
  description = "Maximum number of instances in ASG"
}

variable "cpu_target" {
  type        = number
  description = "Average CPU % the web fleet is kept at: nodes are added above it and removed below it"
}
# Working-hours schedule (ADR 0026). Validated in the ASG module.
variable "web_schedule_enabled" {
  type        = bool
  description = "Scale the web servers to 0 outside working hours. false = servers run 24/7"
}

variable "web_schedule_time_zone" {
  type        = string
  description = "IANA time zone of the schedule times (Asia/Singapore is UTC+8)"
}

variable "web_schedule_days" {
  type        = string
  description = "Days the web servers run, as a cron day-of-week field: MON-FRI, MON-SAT or * (every day)"
}

variable "web_schedule_start" {
  type        = string
  description = "Time (HH:MM, 24-hour) the web servers start; the site is up about 10 minutes later"
}

variable "web_schedule_stop" {
  type        = string
  description = "Time (HH:MM, 24-hour) all web servers are terminated"
}
