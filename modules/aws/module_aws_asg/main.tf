# Auto Scaling Group
resource "aws_autoscaling_group" "web" {
  name_prefix = "asg-"

  vpc_zone_identifier = var.subnet_ids

  min_size         = var.min_size
  desired_capacity = var.desired_capacity
  max_size         = var.max_size

  launch_template {
    id = var.launch_template_id
    # An explicit number, not "$Latest": when the template changes, this value changes,
    # so Terraform updates the ASG and the instance_refresh block below starts by itself.
    version = var.launch_template_version
  }

  target_group_arns = var.target_group_arns

  health_check_type = "ELB"
  # Nodes return nothing until Puppet has deployed the site, so the grace period must cover
  # boot plus the first Puppet run (with its retries). An instance refresh also waits this long.
  health_check_grace_period = 600

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "online-app-instance"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
    # The scaling policy changes desired_capacity at runtime. Without this,
    # every apply would reset the fleet to var.desired_capacity and undo scale-out.
    # var.desired_capacity is therefore only the initial size when the ASG is created.
    # min_size: the working-hours schedule sets it to 0 at night. Without this, an apply at night
    # would reset it to var.min_size and start the servers. ignore_changes cannot depend on a
    # variable, so it is ignored even when the schedule is off: var.min_size reaches an existing
    # group only through the schedule's start action (ADR 0026).
    ignore_changes = [desired_capacity, min_size]
  }
}

# ---------- Working-hours schedule ----------
# Outside working hours the group runs no servers. Only min_size and desired_capacity change:
# max_size stays under Terraform's control (-1 = leave unchanged).

locals {
  start_hm = split(":", var.schedule_start)
  stop_hm  = split(":", var.schedule_stop)

  # Cron: minute hour day-of-month month day-of-week, in var.schedule_time_zone.
  start_recurrence = "${tonumber(local.start_hm[1])} ${tonumber(local.start_hm[0])} * * ${var.schedule_days}"
  stop_recurrence  = "${tonumber(local.stop_hm[1])} ${tonumber(local.stop_hm[0])} * * ${var.schedule_days}"
}

# Start of the working day: back to the normal fleet size. New servers serve the site once boot
# plus the first Puppet run are done (about 10 minutes).
resource "aws_autoscaling_schedule" "start" {
  count = var.schedule_enabled ? 1 : 0

  scheduled_action_name  = "working-hours-start"
  autoscaling_group_name = aws_autoscaling_group.web.name
  recurrence             = local.start_recurrence
  time_zone              = var.schedule_time_zone

  min_size         = var.min_size
  desired_capacity = var.desired_capacity
  max_size         = -1

  lifecycle {
    precondition {
      condition     = var.schedule_start != var.schedule_stop
      error_message = "schedule_start and schedule_stop must be different times."
    }
  }
}

# End of the working day: terminate every server.
resource "aws_autoscaling_schedule" "stop" {
  count = var.schedule_enabled ? 1 : 0

  scheduled_action_name  = "working-hours-stop"
  autoscaling_group_name = aws_autoscaling_group.web.name
  recurrence             = local.stop_recurrence
  time_zone              = var.schedule_time_zone

  min_size         = 0
  desired_capacity = 0
  max_size         = -1
}

# Target tracking: keep the group's average CPU near var.cpu_target, between min_size and max_size.
# AWS creates and manages the high and low CloudWatch alarms itself, so the fleet scales out
# under load and back in when load drops. Scale-in is gradual and never goes below min_size.
resource "aws_autoscaling_policy" "cpu_target" {
  name                   = "cpu-target-tracking"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.web.name

  # A new node serves nothing until boot plus the first Puppet run are done (the health check
  # grace period). Until then its CPU is left out of the average, so the policy does not add
  # more nodes while the first ones are still starting.
  estimated_instance_warmup = 600

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value     = var.cpu_target
    disable_scale_in = false
  }
}
