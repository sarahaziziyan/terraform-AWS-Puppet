locals {
  puppet_master_fqdn = "puppet.internal.puppet-server.com"
}

# Security groups (ALB and web)
module "module_aws_security_groups" {
  source = "./modules/aws/module_aws_security_groups"

  vpc_id = var.vpc_id
}

# Puppet master (instance and its security group)
module "module_aws_ec2_puppet_master" {
  source                 = "./modules/aws/module_aws_ec2_puppet_master"
  vpc_id                 = var.vpc_id
  subnet_id              = var.subnet_id
  key_name               = var.key_name
  web_security_group_id  = module.module_aws_security_groups.web_security_group_id
  puppet_master_fqdn     = local.puppet_master_fqdn
  puppet_autosign_secret = var.puppet_autosign_secret
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

  key_name               = var.key_name
  security_group_ids     = [module.module_aws_security_groups.web_security_group_id]
  site_repo_url          = var.site_repo_url
  site_repo_branch       = var.site_repo_branch
  puppet_master_fqdn     = local.puppet_master_fqdn
  puppet_autosign_secret = var.puppet_autosign_secret
}

# Application Load Balancer
module "module_aws_alb" {
  source = "./modules/aws/module_aws_alb"

  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = [module.module_aws_security_groups.alb_security_group_id]
}

# Auto Scaling Group
module "module_aws_asg" {
  source = "./modules/aws/module_aws_asg"

  subnet_ids         = var.subnet_ids
  launch_template_id = module.module_aws_launch_template.id
  target_group_arns  = [module.module_aws_alb.target_group_arn]

  min_size         = var.asg_min_size
  desired_capacity = var.asg_desired_capacity
  max_size         = var.asg_max_size
  cpu_threshold    = var.cpu_threshold
}
