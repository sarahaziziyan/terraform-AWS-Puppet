# Wiring tests for the root module.
# Module behaviour is tested inside each module (modules/aws/<module>/tests). This file only
# checks that the root connects the modules and passes inputs through. It stays in this
# repository when the modules move to their own repositories.
# Run from the repository root:  terraform init -backend=false && terraform test

# Mocked values are random strings by default. The provider validates ARN and ID formats,
# so the mock returns well-formed ones.
mock_provider "aws" {
  mock_resource "aws_lb" {
    defaults = {
      arn = "arn:aws:elasticloadbalancing:ap-southeast-1:123456789012:loadbalancer/app/alb-test/0123456789abcdef"
    }
  }

  mock_resource "aws_lb_target_group" {
    defaults = {
      arn = "arn:aws:elasticloadbalancing:ap-southeast-1:123456789012:targetgroup/tg-test/0123456789abcdef"
    }
  }

  mock_resource "aws_autoscaling_policy" {
    defaults = {
      arn = "arn:aws:autoscaling:ap-southeast-1:123456789012:scalingPolicy:11111111-2222-3333-4444-555555555555:autoScalingGroupName/asg-test:policyName/cpu-scale-out"
    }
  }

  mock_resource "aws_cloudfront_distribution" {
    defaults = {
      domain_name = "d1234abcd.cloudfront.net"
    }
  }

  mock_data "aws_ec2_managed_prefix_list" {
    defaults = {
      id = "pl-31a34658"
    }
  }

  mock_resource "aws_launch_template" {
    defaults = {
      id             = "lt-0123456789abcdef0"
      latest_version = 7
    }
  }
}

variables {
  region                 = "ap-southeast-1"
  key_name               = "test-key"
  vpc_id                 = "vpc-0123456789abcdef0"
  subnet_ids             = ["subnet-0aaaaaaaaaaaaaaa1", "subnet-0bbbbbbbbbbbbbbb2"]
  subnet_id              = "subnet-0aaaaaaaaaaaaaaa1"
  puppet_autosign_secret = "unit-test-secret"
  site_repo_url          = "https://example.com/acme/site.git"
  site_repo_branch       = "main"
  asg_min_size           = 1
  asg_desired_capacity   = 2
  asg_max_size           = 4
  cpu_threshold          = 70
}

# All six modules must accept what the root gives them (names, types, required inputs).
# A renamed module variable or output makes this run fail.
run "stack_composes" {
  command = apply

  assert {
    condition     = output.asg_name != null && output.asg_name != ""
    error_message = "The stack must produce an Auto Scaling Group."
  }
}

# The asg_* root variables must reach the ASG unchanged and in the right order.
run "asg_sizes_flow_from_root_variables" {
  command = apply

  assert {
    condition     = output.asg_min_size == var.asg_min_size
    error_message = "asg_min_size must reach the ASG as min_size."
  }

  assert {
    condition     = output.asg_desired_capacity == var.asg_desired_capacity
    error_message = "asg_desired_capacity must reach the ASG as desired_capacity."
  }

  assert {
    condition     = output.asg_max_size == var.asg_max_size
    error_message = "asg_max_size must reach the ASG as max_size."
  }
}

# Known issue 2: the ASG must use the template's real version number, so a template change
# starts an instance refresh. The mock returns 7, so a hard-coded or "$Latest" value fails.
run "asg_uses_launch_template_latest_version" {
  command = apply

  assert {
    condition     = module.module_aws_asg.launch_template_version == "7"
    error_message = "The ASG must use module_aws_launch_template.latest_version as its launch template version."
  }
}

# Known issue 10: visitors use HTTPS through CloudFront, which must forward to this stack's ALB.
run "cloudfront_fronts_the_alb" {
  command = apply

  assert {
    condition     = module.module_aws_cloudfront.origin_domain_name == output.alb_dns_name
    error_message = "CloudFront must use this stack's ALB as its origin."
  }

  assert {
    condition     = output.site_url == "https://d1234abcd.cloudfront.net"
    error_message = "site_url must be the HTTPS CloudFront address."
  }
}

# The docs and the integration checks rely on these outputs (alb_dns_name, target_group_arn...).
run "root_outputs_are_populated" {
  command = apply

  assert {
    condition     = output.alb_dns_name != null && output.alb_zone_id != null
    error_message = "alb_dns_name and alb_zone_id must be populated."
  }

  assert {
    condition     = output.target_group_arn != null
    error_message = "target_group_arn must be populated."
  }

  assert {
    condition     = output.puppet_master_private_ip != null
    error_message = "puppet_master_private_ip must be populated."
  }
}
