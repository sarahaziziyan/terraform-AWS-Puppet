output "site_url" {
  description = "HTTPS address of the website (CloudFront)"
  value       = module.cdn.url
}

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution (for cache invalidations)"
  value       = module.cdn.distribution_id
}

output "puppet_master_private_ip" {
  description = "Private IP of the Puppet master"
  value       = module.puppet_server.private_ip
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer. Reachable only from CloudFront; use site_url"
  value       = module.alb.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = module.alb.zone_id
}

output "target_group_arn" {
  description = "ARN of the Target Group"
  value       = module.alb.target_group_arn
}

output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = module.web_asg.name
}

output "asg_min_size" {
  description = "Minimum size of the Auto Scaling Group"
  value       = module.web_asg.min_size
}

output "asg_desired_capacity" {
  description = "Desired capacity of the Auto Scaling Group"
  value       = module.web_asg.desired_capacity
}

output "asg_max_size" {
  description = "Maximum size of the Auto Scaling Group"
  value       = module.web_asg.max_size
}

