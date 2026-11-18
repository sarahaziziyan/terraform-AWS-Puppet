# Unit tests for module_aws_alb.
# Self-contained: the AWS provider is mocked, so no credentials or real resources are needed.
# Run from this module's folder:  terraform init && terraform test

# Mocked values are random strings by default. The provider validates ARN formats,
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

  mock_resource "aws_lb_listener" {
    defaults = {
      arn = "arn:aws:elasticloadbalancing:ap-southeast-1:123456789012:listener/app/alb-test/0123456789abcdef/0123456789abcdef"
    }
  }
}

variables {
  vpc_id              = "vpc-0123456789abcdef0"
  subnet_ids          = ["subnet-0aaaaaaaaaaaaaaa1", "subnet-0bbbbbbbbbbbbbbb2"]
  security_group_ids  = ["sg-0123456789abcdef0"]
  origin_header_name  = "X-Origin-Verify"
  origin_header_value = "TestOriginSecret0123456789"
}

# The load balancer must sit in the subnets and security groups the caller passes in.
run "alb_uses_given_network" {
  command = apply

  assert {
    condition     = aws_lb.web.subnets == toset(var.subnet_ids)
    error_message = "The ALB must be placed in exactly the subnets passed to the module."
  }

  assert {
    condition     = aws_lb.web.security_groups == toset(var.security_group_ids)
    error_message = "The ALB must use exactly the security groups passed to the module."
  }
}

# Traffic enters on HTTP 80.
run "listener_is_http_80" {
  command = apply

  assert {
    condition     = aws_lb_listener.http.port == 80 && aws_lb_listener.http.protocol == "HTTP"
    error_message = "The listener must be HTTP on port 80."
  }

  assert {
    condition     = aws_lb_listener.http.load_balancer_arn == aws_lb.web.arn
    error_message = "The listener must belong to the web ALB."
  }
}

# Known issue 21: the security group admits every CloudFront distribution, so the listener
# must reject requests that do not carry this stack's secret header.
run "requests_without_origin_header_are_rejected" {
  command = apply

  assert {
    condition = (
      aws_lb_listener.http.default_action[0].type == "fixed-response" &&
      aws_lb_listener.http.default_action[0].fixed_response[0].status_code == "403"
    )
    error_message = "The listener's default action must answer 403, never forward."
  }

  assert {
    condition     = aws_lb_listener.http.default_action[0].target_group_arn == null || aws_lb_listener.http.default_action[0].target_group_arn == ""
    error_message = "The default action must not forward to the target group."
  }
}

run "requests_with_origin_header_reach_the_web_nodes" {
  command = apply

  assert {
    condition     = aws_lb_listener_rule.from_cloudfront.listener_arn == aws_lb_listener.http.arn
    error_message = "The header rule must belong to the HTTP listener."
  }

  assert {
    condition = (
      one(aws_lb_listener_rule.from_cloudfront.condition).http_header[0].http_header_name == "X-Origin-Verify" &&
      nonsensitive(one(aws_lb_listener_rule.from_cloudfront.condition).http_header[0].values) == toset(["TestOriginSecret0123456789"])
    )
    error_message = "The rule must match exactly the header name and secret value passed to the module."
  }

  assert {
    condition     = length(aws_lb_listener_rule.from_cloudfront.condition) == 1
    error_message = "The header must be the rule's only condition."
  }

  assert {
    condition = (
      aws_lb_listener_rule.from_cloudfront.action[0].type == "forward" &&
      aws_lb_listener_rule.from_cloudfront.action[0].target_group_arn == aws_lb_target_group.web.arn
    )
    error_message = "Requests with the header must be forwarded to the web target group."
  }
}

# The ALB treats * and ? in header values as wildcards; a weak or wildcard value must be refused.
run "weak_origin_header_value_is_rejected" {
  command = plan

  variables {
    origin_header_value = "*"
  }

  expect_failures = [var.origin_header_value]
}

# The target group must match how nginx nodes are registered (instance targets, HTTP 80).
run "target_group_matches_web_nodes" {
  command = apply

  assert {
    condition     = aws_lb_target_group.web.port == 80 && aws_lb_target_group.web.protocol == "HTTP"
    error_message = "The target group must send HTTP to port 80."
  }

  assert {
    condition     = aws_lb_target_group.web.target_type == "instance"
    error_message = "The target group must use instance targets, because the ASG registers instances."
  }

  assert {
    condition     = aws_lb_target_group.web.vpc_id == var.vpc_id
    error_message = "The target group must be created in the VPC passed to the module."
  }
}

# The ASG replaces nodes based on this health check, so its settings are part of the contract.
run "health_check_expects_200_on_root" {
  command = apply

  assert {
    condition     = aws_lb_target_group.web.health_check[0].enabled
    error_message = "The health check must be enabled."
  }

  assert {
    condition     = aws_lb_target_group.web.health_check[0].path == "/" && aws_lb_target_group.web.health_check[0].matcher == "200"
    error_message = "The health check must request / and expect HTTP 200."
  }

  assert {
    condition     = aws_lb_target_group.web.health_check[0].timeout < aws_lb_target_group.web.health_check[0].interval
    error_message = "The health check timeout must be shorter than its interval."
  }

  assert {
    condition     = aws_lb_target_group.web.health_check[0].healthy_threshold == 2 && aws_lb_target_group.web.health_check[0].unhealthy_threshold == 2
    error_message = "Healthy and unhealthy thresholds must both be 2."
  }
}

# The root module and the ASG module depend on these outputs.
run "outputs_expose_alb_and_target_group" {
  command = apply

  assert {
    condition     = output.target_group_arn == aws_lb_target_group.web.arn
    error_message = "target_group_arn must be the web target group's ARN."
  }

  assert {
    condition     = output.dns_name == aws_lb.web.dns_name && output.zone_id == aws_lb.web.zone_id
    error_message = "dns_name and zone_id must come from the web ALB."
  }
}
