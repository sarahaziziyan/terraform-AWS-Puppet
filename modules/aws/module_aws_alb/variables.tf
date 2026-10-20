variable "vpc_id" {
  type        = string
  description = "VPC ID for the target group"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnet IDs for the ALB (at least two AZs)"
}

variable "security_group_ids" {
  type        = list(string)
  description = "Security group IDs attached to the ALB"
}
