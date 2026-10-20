# Auto Scaling Group
resource "aws_autoscaling_group" "web" {
  name_prefix = "asg-"

  vpc_zone_identifier = var.subnet_ids

  min_size         = var.min_size
  desired_capacity = var.desired_capacity
  max_size         = var.max_size

  launch_template {
    id      = var.launch_template_id
    version = "$Latest"
  }

  target_group_arns = var.target_group_arns

  health_check_type         = "ELB"
  health_check_grace_period = 180

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "online-course-instance"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Scaling Policy - Scale out when CPU > threshold
resource "aws_autoscaling_policy" "cpu_scale_out" {
  name               = "cpu-scale-out"
  scaling_adjustment = 1
  adjustment_type    = "ChangeInCapacity"
  cooldown           = 300
  policy_type        = "SimpleScaling"

  autoscaling_group_name = aws_autoscaling_group.web.name
}

# CloudWatch Metric Alarm for CPU Utilization
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "web-asg-cpu-high-${aws_autoscaling_group.web.name}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = var.cpu_threshold

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }

  alarm_description = "Scale out when CPU utilization exceeds ${var.cpu_threshold}%"
  alarm_actions     = [aws_autoscaling_policy.cpu_scale_out.arn]
}
