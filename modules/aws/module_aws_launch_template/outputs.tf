output "id" {
  description = "ID of the launch template"
  value       = aws_launch_template.web.id
}

output "latest_version" {
  description = "Latest version number of the launch template. Pass it to the ASG so a template change starts an instance refresh"
  value       = aws_launch_template.web.latest_version
}

output "instance_profile_name" {
  description = "Instance profile attached to the instances (lets them read the autosign secret)"
  value       = aws_launch_template.web.iam_instance_profile[0].name
}
