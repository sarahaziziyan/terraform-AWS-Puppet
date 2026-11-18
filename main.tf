locals {
  puppet_master_fqdn = "puppet.internal.puppet-server.com"
  origin_header_name = "X-Origin-Verify"
}

# Secret header value that CloudFront adds and the ALB requires (known issue 21), so only this
# stack's distribution can reach the ALB. It is stored in the (encrypted) state, and AWS shows it
# in the CloudFront and listener rule settings. Letters and digits only: the ALB treats * and ?
# as wildcards. Rotate with: terraform apply -replace=random_password.origin_header
resource "random_password" "origin_header" {
  length  = 40
  special = false
}

# Security groups (ALB and web)
module "module_aws_security_groups" {
  source = "./modules/aws/module_aws_security_groups"

  vpc_id = var.vpc_id
}

# Puppet master (instance and its security group)
module "module_aws_ec2_puppet_master" {
  source                = "./modules/aws/module_aws_ec2_puppet_master"
  vpc_id                = var.vpc_id
  subnet_id             = var.subnet_id
  key_name              = var.key_name
  web_security_group_id = module.module_aws_security_groups.web_security_group_id
  puppet_master_fqdn    = local.puppet_master_fqdn

  autosign_secret_parameter_name = var.autosign_secret_parameter_name
  instance_profile_name          = var.puppet_master_instance_profile_name
}

# Internal DNS (private zone and Puppet master record)
module "module_aws_dns" {
  source = "./modules/aws/module_aws_dns"

  vpc_id                   = var.vpc_id
  puppet_master_fqdn       = local.puppet_master_fqdn
  puppet_master_private_ip = module.module_aws_ec2_puppet_master.private_ip
}

# Launch template for the web nodes
module "module_aws_launch_template" {
  source = "./modules/aws/module_aws_launch_template"

  key_name           = var.key_name
  security_group_ids = [module.module_aws_security_groups.web_security_group_id]
  site_repo_url      = var.site_repo_url
  site_repo_branch   = var.site_repo_branch
  puppet_master_fqdn = local.puppet_master_fqdn

  autosign_secret_parameter_name = var.autosign_secret_parameter_name
  instance_profile_name          = var.web_node_instance_profile_name
}

# Application Load Balancer
module "module_aws_alb" {
  source = "./modules/aws/module_aws_alb"

  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = [module.module_aws_security_groups.alb_security_group_id]

  origin_header_name  = local.origin_header_name
  origin_header_value = random_password.origin_header.result
}

# CloudFront: HTTPS for visitors, forwarding to the ALB
module "module_aws_cloudfront" {
  source = "./modules/aws/module_aws_cloudfront"

  alb_dns_name = module.module_aws_alb.dns_name

  origin_header_name  = local.origin_header_name
  origin_header_value = random_password.origin_header.result
}

# Auto Scaling Group
module "module_aws_asg" {
  source = "./modules/aws/module_aws_asg"

  subnet_ids              = var.subnet_ids
  launch_template_id      = module.module_aws_launch_template.id
  launch_template_version = module.module_aws_launch_template.latest_version
  target_group_arns       = [module.module_aws_alb.target_group_arn]

  min_size         = var.asg_min_size
  desired_capacity = var.asg_desired_capacity
  max_size         = var.asg_max_size
  cpu_threshold    = var.cpu_threshold
}
