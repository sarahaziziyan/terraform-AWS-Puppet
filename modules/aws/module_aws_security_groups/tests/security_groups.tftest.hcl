# Unit tests for module_aws_security_groups.
# Self-contained: the AWS provider is mocked, so no credentials or real resources are needed.
# Run from this module's folder:  terraform init && terraform test

mock_provider "aws" {
  mock_data "aws_region" {
    defaults = {
      region = "eu-west-1"
    }
  }

  mock_data "aws_ec2_managed_prefix_list" {
    defaults = {
      id = "pl-31a34658"
    }
  }
}

# Each prefix list gets its own ID, so a test can tell them apart.
override_data {
  target = data.aws_ec2_managed_prefix_list.instance_connect
  values = {
    id = "pl-0instanceconnect01"
  }
}

variables {
  vpc_id = "vpc-0123456789abcdef0"
}

# Known issue 10: only CloudFront may reach the ALB (HTTP 80), so visitors cannot bypass HTTPS.
run "alb_accepts_http_only_from_cloudfront" {
  command = apply

  assert {
    condition     = aws_vpc_security_group_ingress_rule.alb_http.security_group_id == aws_security_group.alb.id
    error_message = "The HTTP rule must belong to the ALB security group."
  }

  assert {
    condition     = data.aws_ec2_managed_prefix_list.cloudfront.name == "com.amazonaws.global.cloudfront.origin-facing"
    error_message = "The ALB must look up CloudFront's origin-facing prefix list."
  }

  assert {
    condition = (
      aws_vpc_security_group_ingress_rule.alb_http.prefix_list_id == data.aws_ec2_managed_prefix_list.cloudfront.id &&
      aws_vpc_security_group_ingress_rule.alb_http.cidr_ipv4 == null
    )
    error_message = "The ALB must accept HTTP only from CloudFront's prefix list, not from 0.0.0.0/0."
  }

  assert {
    condition = (
      aws_vpc_security_group_ingress_rule.alb_http.ip_protocol == "tcp" &&
      aws_vpc_security_group_ingress_rule.alb_http.from_port == 80 &&
      aws_vpc_security_group_ingress_rule.alb_http.to_port == 80
    )
    error_message = "The ALB rule must open TCP port 80 only."
  }
}

# Web nodes must not be reachable from the internet: HTTP only from the ALB group.
run "web_accepts_http_only_from_alb" {
  command = apply

  assert {
    condition     = aws_vpc_security_group_ingress_rule.http.security_group_id == aws_security_group.web.id
    error_message = "The HTTP rule must be attached to the web security group."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.http.referenced_security_group_id == aws_security_group.alb.id
    error_message = "Web nodes must accept HTTP from the ALB security group."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.http.cidr_ipv4 == null
    error_message = "The web HTTP rule must not use a CIDR; it must reference the ALB security group."
  }

  assert {
    condition = (
      aws_vpc_security_group_ingress_rule.http.from_port == 80 &&
      aws_vpc_security_group_ingress_rule.http.to_port == 80
    )
    error_message = "The web HTTP rule must be port 80 only."
  }
}

# SSH is limited to the EC2 Instance Connect range, never the whole internet.
run "web_ssh_limited_to_instance_connect" {
  command = apply

  assert {
    condition     = aws_vpc_security_group_ingress_rule.ssh.security_group_id == aws_security_group.web.id
    error_message = "The SSH rule must be attached to the web security group."
  }

  # Known issue 8: the range comes from the region's managed list, not a hard-coded CIDR.
  assert {
    condition = (
      aws_vpc_security_group_ingress_rule.ssh.prefix_list_id == "pl-0instanceconnect01" &&
      aws_vpc_security_group_ingress_rule.ssh.cidr_ipv4 == null
    )
    error_message = "SSH must be limited to the region's EC2 Instance Connect prefix list, not a fixed address range."
  }

  assert {
    condition     = data.aws_ec2_managed_prefix_list.instance_connect.name == "com.amazonaws.eu-west-1.ec2-instance-connect"
    error_message = "The prefix list must be the one for the current region."
  }

  assert {
    condition = (
      aws_vpc_security_group_ingress_rule.ssh.from_port == 22 &&
      aws_vpc_security_group_ingress_rule.ssh.to_port == 22
    )
    error_message = "The SSH rule must be port 22 only."
  }
}

# Both groups live in the VPC passed in, and outbound traffic is open (package installs, Puppet).
run "groups_use_given_vpc_and_allow_egress" {
  command = apply

  assert {
    condition     = aws_security_group.alb.vpc_id == var.vpc_id && aws_security_group.web.vpc_id == var.vpc_id
    error_message = "Both security groups must be created in the VPC passed to the module."
  }

  assert {
    condition     = aws_vpc_security_group_egress_rule.alb.ip_protocol == "-1" && aws_vpc_security_group_egress_rule.web.ip_protocol == "-1"
    error_message = "Both groups must allow all outbound traffic."
  }
}

# Other modules depend on these two outputs.
run "outputs_expose_group_ids" {
  command = apply

  assert {
    condition     = output.alb_security_group_id == aws_security_group.alb.id
    error_message = "alb_security_group_id must be the ALB group's ID."
  }

  assert {
    condition     = output.web_security_group_id == aws_security_group.web.id
    error_message = "web_security_group_id must be the web group's ID."
  }
}
