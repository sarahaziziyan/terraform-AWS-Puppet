# Unit tests for module_aws_asg.
# Self-contained: the AWS provider is mocked, so no credentials or real resources are needed.
# Run from this module's folder:  terraform init && terraform test

# Mocked values are random strings by default. The provider validates ARN formats,
# so the mock returns a well-formed one.
mock_provider "aws" {
  mock_resource "aws_autoscaling_policy" {
    defaults = {
      arn = "arn:aws:autoscaling:ap-southeast-1:123456789012:scalingPolicy:11111111-2222-3333-4444-555555555555:autoScalingGroupName/asg-test:policyName/cpu-scale-out"
    }
  }
}

variables {
  subnet_ids         = ["subnet-0aaaaaaaaaaaaaaa1", "subnet-0bbbbbbbbbbbbbbb2"]
  launch_template_id = "lt-0123456789abcdef0"
  target_group_arns  = ["arn:aws:elasticloadbalancing:ap-southeast-1:123456789012:targetgroup/tg-test/0123456789abcdef"]
  min_size           = 1
  desired_capacity   = 2
  max_size           = 4
  cpu_threshold      = 70
}

# Fleet size is controlled by the caller; the module must not change the numbers.
run "sizes_pass_through" {
  command = apply

  assert {
    condition = (
      aws_autoscaling_group.web.min_size == 1 &&
      aws_autoscaling_group.web.desired_capacity == 2 &&
      aws_autoscaling_group.web.max_size == 4
    )
    error_message = "min_size, desired_capacity and max_size must equal the module inputs."
  }

  assert {
    condition     = output.min_size == 1 && output.desired_capacity == 2 && output.max_size == 4
    error_message = "The size outputs must report the same numbers as the inputs."
  }
}

# The group must launch from the given template, in the given subnets, behind the given target group.
run "group_uses_given_template_subnets_and_targets" {
  command = apply

  assert {
    condition     = aws_autoscaling_group.web.launch_template[0].id == var.launch_template_id
    error_message = "The ASG must use the launch template passed to the module."
  }

  assert {
    condition     = aws_autoscaling_group.web.launch_template[0].version == "$Latest"
    error_message = "The ASG must use the $Latest launch template version so new instances get the newest template."
  }

  assert {
    condition     = aws_autoscaling_group.web.vpc_zone_identifier == toset(var.subnet_ids)
    error_message = "The ASG must launch into exactly the subnets passed to the module."
  }

  assert {
    condition     = aws_autoscaling_group.web.target_group_arns == toset(var.target_group_arns)
    error_message = "The ASG must register instances with the target groups passed to the module."
  }
}

# Self-healing: unhealthy nodes (as seen by the load balancer) are replaced, after a boot grace period.
run "self_healing_uses_elb_health_check" {
  command = apply

  assert {
    condition     = aws_autoscaling_group.web.health_check_type == "ELB"
    error_message = "The ASG must use ELB health checks, otherwise a node with a dead nginx is never replaced."
  }

  assert {
    condition     = aws_autoscaling_group.web.health_check_grace_period == 180
    error_message = "The grace period must be 180 seconds so nodes can finish bootstrapping."
  }
}

# Launch template changes must roll out without taking the whole fleet down.
run "rolling_refresh_keeps_half_the_fleet" {
  command = apply

  assert {
    condition     = aws_autoscaling_group.web.instance_refresh[0].strategy == "Rolling"
    error_message = "Instance refresh must use the Rolling strategy."
  }

  assert {
    condition     = aws_autoscaling_group.web.instance_refresh[0].preferences[0].min_healthy_percentage == 50
    error_message = "Instance refresh must keep at least 50% of the fleet healthy."
  }
}

# Instances need the Name tag to be identifiable in the console.
run "name_tag_propagates_to_instances" {
  command = apply

  assert {
    condition = anytrue([
      for t in aws_autoscaling_group.web.tag :
      t.key == "Name" && t.value == "online-course-instance" && t.propagate_at_launch
    ])
    error_message = "The ASG must propagate a Name tag of online-course-instance to its instances."
  }
}

# Scale-out: the CPU alarm watches this group and triggers a +1 instance policy.
run "cpu_alarm_triggers_scale_out" {
  command = apply

  assert {
    condition     = aws_cloudwatch_metric_alarm.cpu_high.threshold == var.cpu_threshold
    error_message = "The alarm threshold must equal the cpu_threshold input."
  }

  assert {
    condition = (
      aws_cloudwatch_metric_alarm.cpu_high.metric_name == "CPUUtilization" &&
      aws_cloudwatch_metric_alarm.cpu_high.namespace == "AWS/EC2" &&
      aws_cloudwatch_metric_alarm.cpu_high.statistic == "Average" &&
      aws_cloudwatch_metric_alarm.cpu_high.comparison_operator == "GreaterThanThreshold"
    )
    error_message = "The alarm must fire when average EC2 CPUUtilization is greater than the threshold."
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.cpu_high.evaluation_periods == 2 && aws_cloudwatch_metric_alarm.cpu_high.period == 120
    error_message = "The alarm must evaluate 2 periods of 120 seconds."
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.cpu_high.dimensions["AutoScalingGroupName"] == aws_autoscaling_group.web.name
    error_message = "The alarm must measure this Auto Scaling Group, not another one."
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.cpu_high.alarm_actions == toset([aws_autoscaling_policy.cpu_scale_out.arn])
    error_message = "The alarm must trigger the scale-out policy."
  }

  assert {
    condition = (
      aws_autoscaling_policy.cpu_scale_out.autoscaling_group_name == aws_autoscaling_group.web.name &&
      aws_autoscaling_policy.cpu_scale_out.adjustment_type == "ChangeInCapacity" &&
      aws_autoscaling_policy.cpu_scale_out.scaling_adjustment == 1 &&
      aws_autoscaling_policy.cpu_scale_out.cooldown == 300
    )
    error_message = "The policy must add 1 instance to this group with a 300 second cooldown."
  }
}

# A different threshold must flow through to the alarm (guards against a hard-coded value).
run "cpu_threshold_is_configurable" {
  command = apply

  variables {
    cpu_threshold = 85
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.cpu_high.threshold == 85
    error_message = "Changing cpu_threshold must change the alarm threshold."
  }
}
