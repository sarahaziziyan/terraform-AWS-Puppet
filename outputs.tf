output "puppet_master_private_ip" {
  description = "Private IP of the Puppet master"
  value       = module.module_aws_ec2_puppet_master.private_ip
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.module_aws_alb.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = module.module_aws_alb.zone_id
}

output "target_group_arn" {
  description = "ARN of the Target Group"
  value       = module.module_aws_alb.target_group_arn
}

output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = module.module_aws_asg.name
}

output "asg_min_size" {
  description = "Minimum size of the Auto Scaling Group"
  value       = module.module_aws_asg.min_size
}

output "asg_desired_capacity" {
  description = "Desired capacity of the Auto Scaling Group"
  value       = module.module_aws_asg.desired_capacity
}

output "asg_max_size" {
  description = "Maximum size of the Auto Scaling Group"
  value       = module.module_aws_asg.max_size
}

