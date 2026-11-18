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

variable "origin_header_name" {
  type        = string
  description = "Name of the header CloudFront adds to every request it forwards to the ALB"
}

variable "origin_header_value" {
  type        = string
  sensitive   = true
  description = "Secret value of that header. Requests without it get 403. Letters and digits only (ALB treats * and ? as wildcards)"

  validation {
    condition     = can(regex("^[A-Za-z0-9]{16,128}$", var.origin_header_value))
    error_message = "origin_header_value must be 16 to 128 letters and digits."
  }
}
