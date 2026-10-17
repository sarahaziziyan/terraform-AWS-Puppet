variable "vpc_id" {
  type        = string
  description = "VPC ID for the ALB and ASG"
  default     = "vpc-00cb260ae54bf57d7"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnet IDs for the ALB and ASG (at least two AZs)"
  default = [
    "subnet-088e08ec462af6a3e",
    "subnet-080c39aa888430837"
  ]
}

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