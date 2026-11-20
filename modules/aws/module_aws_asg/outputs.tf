output "name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.web.name
}

output "min_size" {
  description = "Minimum size of the Auto Scaling Group"
  value       = aws_autoscaling_group.web.min_size
}

output "desired_capacity" {
  description = "Desired capacity of the Auto Scaling Group"
  value       = aws_autoscaling_group.web.desired_capacity
}

output "max_size" {
  description = "Maximum size of the Auto Scaling Group"
  value       = aws_autoscaling_group.web.max_size
}

output "launch_template_version" {
  description = "Launch template version the Auto Scaling Group uses"
  value       = aws_autoscaling_group.web.launch_template[0].version
}

output "cpu_target" {
  description = "Average CPU % the target tracking policy keeps the group at"
  value       = one(aws_autoscaling_policy.cpu_target.target_tracking_configuration).target_value
}

output "schedule" {
  description = "Working-hours schedule (cron recurrences and time zone), or null when it is off"
  value = var.schedule_enabled ? {
    time_zone        = one(aws_autoscaling_schedule.start).time_zone
    start_recurrence = one(aws_autoscaling_schedule.start).recurrence
    stop_recurrence  = one(aws_autoscaling_schedule.stop).recurrence
  } : null
}
