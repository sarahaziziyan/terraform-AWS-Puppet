variable "subnet_ids" {
  type        = list(string)
  description = "Subnet IDs for the ASG (at least two AZs)"
}

variable "launch_template_id" {
  type        = string
  description = "ID of the launch template used by the ASG"
}

variable "launch_template_version" {
  type        = number
  description = "Launch template version the ASG uses. Pass the template's latest_version: a new number starts a rolling instance refresh"
}

variable "target_group_arns" {
  type        = list(string)
  description = "Target group ARNs the ASG registers instances with"
}

variable "min_size" {
  type        = number
  description = "Minimum number of instances in ASG"
}

variable "desired_capacity" {
  type        = number
  description = "Number of instances when the ASG is first created. Ignored afterwards: the scaling policy owns the running count"
}

variable "max_size" {
  type        = number
  description = "Maximum number of instances in ASG"
}

variable "cpu_threshold" {
  type        = number
  description = "CPU threshold for scaling policy"
}
