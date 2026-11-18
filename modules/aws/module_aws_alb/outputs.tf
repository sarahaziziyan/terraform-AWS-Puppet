output "dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.web.dns_name
}

output "zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = aws_lb.web.zone_id
}

output "target_group_arn" {
  description = "ARN of the Target Group"
  value       = aws_lb_target_group.web.arn
}

output "required_origin_header" {
  description = "Header name and value a request needs to be forwarded to the web nodes"
  sensitive   = true
  value = {
    name  = one(aws_lb_listener_rule.from_cloudfront.condition).http_header[0].http_header_name
    value = one(one(aws_lb_listener_rule.from_cloudfront.condition).http_header[0].values)
  }
}
