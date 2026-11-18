variable "alb_dns_name" {
  type        = string
  description = "DNS name of the Application Load Balancer that CloudFront forwards requests to"
}

variable "origin_header_name" {
  type        = string
  description = "Name of the header CloudFront adds to every request it forwards to the ALB"
}

variable "origin_header_value" {
  type        = string
  sensitive   = true
  description = "Secret value of that header; the ALB rejects requests without it"
}
