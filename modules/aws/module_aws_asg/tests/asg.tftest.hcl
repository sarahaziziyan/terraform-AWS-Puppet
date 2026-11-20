# Unit tests for module_aws_asg.
# Self-contained: the AWS provider is mocked, so no credentials or real resources are needed.
# Run from this module's folder:  terraform init && terraform test

# Mocked values are random strings by default. The provider validates ARN formats,
# so the mock returns a well-formed one.
mock_provider "aws" {
  mock_resource "aws_autoscaling_policy" {
    defaults = {
      arn = "arn:aws:autoscaling:ap-southeast-1:123456789012:scalingPolicy:11111111-2222-3333-4444-555555555555:autoScalingGroupName/asg-test:policyName/cpu-target-tracking"
    }
  }
}

variables {
  subnet_ids              = ["subnet-0aaaaaaaaaaaaaaa1", "subnet-0bbbbbbbbbbbbbbb2"]
  launch_template_id      = "lt-0123456789abcdef0"
  launch_template_version = 3
  target_group_arns       = ["arn:aws:elasticloadbalancing:ap-southeast-1:123456789012:targetgroup/tg-test/0123456789abcdef"]
  min_size                = 1
  desired_capacity        = 2
  max_size                = 4
  cpu_target              = 70

  schedule_enabled   = true
  schedule_time_zone = "Asia/Singapore"
  schedule_days      = "MON-FRI"
  schedule_start     = "09:00"
  schedule_stop      = "18:00"
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

# Regression test for known issue 3: the scaling policy owns desired_capacity after creation.
# The group already exists from the run above, so a different input must not resize it,
# otherwise every apply would undo scale-out. min_size and max_size must still follow the inputs.
run "apply_does_not_reset_desired_capacity" {
  command = apply

  variables {
    desired_capacity = 3
    max_size         = 5
  }

  assert {
    condition     = aws_autoscaling_group.web.desired_capacity == 2
    error_message = "desired_capacity must be ignored after creation (lifecycle ignore_changes), so apply cannot undo scale-out."
  }

  assert {
    condition     = aws_autoscaling_group.web.max_size == 5
    error_message = "max_size must still follow the module input on an existing group."
  }
}

# The group must launch from the given template, in the given subnets, behind the given target group.
run "group_uses_given_template_subnets_and_targets" {
  command = apply

  assert {
    condition     = aws_autoscaling_group.web.launch_template[0].id == var.launch_template_id
    error_message = "The ASG must use the launch template passed to the module."
  }

  # Known issue 2: "$Latest" never changes, so a template change would not start an instance refresh.
  assert {
    condition     = aws_autoscaling_group.web.launch_template[0].version == tostring(var.launch_template_version)
    error_message = "The ASG must use the explicit launch template version passed to the module, not \"$Latest\"."
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

# Regression test for known issue 2: a new template version must change the existing ASG.
# That in-place change is what makes the provider start the instance refresh.
run "new_template_version_updates_existing_group" {
  command = apply

  variables {
    launch_template_version = 4
  }

  assert {
    condition     = aws_autoscaling_group.web.launch_template[0].version == "4"
    error_message = "A new launch template version must update the ASG, so the instance refresh starts."
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
    condition     = aws_autoscaling_group.web.health_check_grace_period == 600
    error_message = "The grace period must be 600 seconds: nodes answer only after boot plus the first Puppet run (up to 4 minutes of retries)."
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

  # During the grace period the ASG counts a new node as healthy whatever the load balancer says.
  # A short warmup would let a refresh move on before the node serves the site (known issue 4).
  assert {
    condition     = try(aws_autoscaling_group.web.instance_refresh[0].preferences[0].instance_warmup, null) == null || try(aws_autoscaling_group.web.instance_refresh[0].preferences[0].instance_warmup, "") == ""
    error_message = "Instance refresh must use the default warmup (the grace period), not a shorter one."
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

# Known issue 14: one target tracking policy on this group's average CPU scales out and back in.
run "cpu_target_tracking_scales_both_ways" {
  command = apply

  assert {
    condition = (
      aws_autoscaling_policy.cpu_target.autoscaling_group_name == aws_autoscaling_group.web.name &&
      aws_autoscaling_policy.cpu_target.policy_type == "TargetTrackingScaling"
    )
    error_message = "The group must use a target tracking policy."
  }

  assert {
    condition     = aws_autoscaling_policy.cpu_target.target_tracking_configuration[0].predefined_metric_specification[0].predefined_metric_type == "ASGAverageCPUUtilization"
    error_message = "The policy must track the group's average CPU utilization."
  }

  assert {
    condition     = aws_autoscaling_policy.cpu_target.target_tracking_configuration[0].target_value == var.cpu_target
    error_message = "The policy's target must equal the cpu_target input."
  }

  assert {
    condition     = aws_autoscaling_policy.cpu_target.target_tracking_configuration[0].disable_scale_in == false
    error_message = "Scale-in must stay enabled, otherwise the fleet never shrinks."
  }

  # New nodes are useless until Puppet has deployed the site; counting their idle CPU early
  # would make the policy think the fleet is fine, or remove them, before they serve anything.
  assert {
    condition     = aws_autoscaling_policy.cpu_target.estimated_instance_warmup == aws_autoscaling_group.web.health_check_grace_period
    error_message = "The policy's instance warmup must match the health check grace period (boot plus the first Puppet run)."
  }
}

# A different target must flow through to the policy (guards against a hard-coded value).
run "cpu_target_is_configurable" {
  command = apply

  variables {
    cpu_target = 45
  }

  assert {
    condition     = aws_autoscaling_policy.cpu_target.target_tracking_configuration[0].target_value == 45
    error_message = "Changing cpu_target must change the policy's target value."
  }

  assert {
    condition     = output.cpu_target == 45
    error_message = "The cpu_target output must report the policy's target value."
  }
}

run "cpu_target_must_be_a_percentage" {
  command = plan

  variables {
    cpu_target = 120
  }

  expect_failures = [var.cpu_target]
}

# ---------- Working-hours schedule (ADR 0026) ----------

# Monday to Friday, 09:00 to 18:00 Singapore time (the file's inputs).
run "schedule_runs_weekday_working_hours" {
  command = apply

  assert {
    condition     = length(aws_autoscaling_schedule.start) == 1 && length(aws_autoscaling_schedule.stop) == 1
    error_message = "With schedule_enabled = true there must be one start and one stop action."
  }

  assert {
    condition = (
      aws_autoscaling_schedule.start[0].recurrence == "0 9 * * MON-FRI" &&
      aws_autoscaling_schedule.stop[0].recurrence == "0 18 * * MON-FRI"
    )
    error_message = "The servers must start at 09:00 and stop at 18:00, Monday to Friday."
  }

  assert {
    condition = (
      aws_autoscaling_schedule.start[0].time_zone == "Asia/Singapore" &&
      aws_autoscaling_schedule.stop[0].time_zone == "Asia/Singapore"
    )
    error_message = "Both actions must use the schedule_time_zone input."
  }

  assert {
    condition = (
      aws_autoscaling_schedule.start[0].autoscaling_group_name == aws_autoscaling_group.web.name &&
      aws_autoscaling_schedule.stop[0].autoscaling_group_name == aws_autoscaling_group.web.name
    )
    error_message = "Both actions must belong to this Auto Scaling Group."
  }
}

# Stop terminates every server; start restores the normal size. Neither touches max_size,
# which stays under Terraform's control.
run "schedule_sizes" {
  command = apply

  assert {
    condition = (
      aws_autoscaling_schedule.stop[0].min_size == 0 &&
      aws_autoscaling_schedule.stop[0].desired_capacity == 0 &&
      aws_autoscaling_schedule.stop[0].max_size == -1
    )
    error_message = "The stop action must set min and desired to 0 and leave max unchanged (-1)."
  }

  assert {
    condition = (
      aws_autoscaling_schedule.start[0].min_size == var.min_size &&
      aws_autoscaling_schedule.start[0].desired_capacity == var.desired_capacity &&
      aws_autoscaling_schedule.start[0].max_size == -1
    )
    error_message = "The start action must restore min_size and desired_capacity and leave max unchanged (-1)."
  }
}

# Days, times and time zone come from the inputs; minutes and hours lose their leading zeros.
run "schedule_uses_given_days_times_and_zone" {
  command = apply

  variables {
    schedule_time_zone = "Europe/Berlin"
    schedule_days      = "MON-SAT"
    schedule_start     = "07:30"
    schedule_stop      = "21:05"
  }

  assert {
    condition = (
      aws_autoscaling_schedule.start[0].recurrence == "30 7 * * MON-SAT" &&
      aws_autoscaling_schedule.stop[0].recurrence == "5 21 * * MON-SAT"
    )
    error_message = "The cron recurrences must be built from schedule_start, schedule_stop and schedule_days."
  }

  assert {
    condition     = aws_autoscaling_schedule.start[0].time_zone == "Europe/Berlin"
    error_message = "The time zone must come from schedule_time_zone."
  }

  assert {
    condition     = output.schedule.start_recurrence == "30 7 * * MON-SAT" && output.schedule.time_zone == "Europe/Berlin"
    error_message = "The schedule output must report the recurrences and time zone."
  }
}

# Off: no scheduled actions, the servers run all the time.
run "schedule_can_be_turned_off" {
  command = apply

  variables {
    schedule_enabled = false
  }

  assert {
    condition     = length(aws_autoscaling_schedule.start) == 0 && length(aws_autoscaling_schedule.stop) == 0
    error_message = "With schedule_enabled = false there must be no scheduled actions."
  }

  assert {
    condition     = output.schedule == null
    error_message = "The schedule output must be null when the schedule is off."
  }
}

# The stop action sets min_size to 0 at night, so an apply must not reset it (Option B, ADR 0026).
# The group exists from the runs above with min_size = 1.
run "apply_does_not_reset_min_size" {
  command = apply

  variables {
    min_size = 2
  }

  assert {
    condition     = aws_autoscaling_group.web.min_size == 1
    error_message = "min_size must be ignored on an existing group (lifecycle ignore_changes), so an apply at night does not start the servers."
  }

  assert {
    condition     = aws_autoscaling_schedule.start[0].min_size == 2
    error_message = "A new min_size must still reach the start action, which applies it at the next working day."
  }
}

run "schedule_rejects_bad_time" {
  command = plan

  variables {
    schedule_start = "9:00"
    schedule_stop  = "24:00"
  }

  expect_failures = [var.schedule_start, var.schedule_stop]
}

run "schedule_rejects_bad_days" {
  command = plan

  variables {
    schedule_days = "MONDAY"
  }

  expect_failures = [var.schedule_days]
}

run "schedule_rejects_equal_start_and_stop" {
  command = plan

  variables {
    schedule_start = "09:00"
    schedule_stop  = "09:00"
  }

  expect_failures = [aws_autoscaling_schedule.start]
}
