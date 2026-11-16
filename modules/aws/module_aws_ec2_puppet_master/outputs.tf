output "private_ip" {
  description = "Private IP of the Puppet master"
  value       = aws_instance.puppet_master.private_ip
}

output "instance_profile_name" {
  description = "Instance profile attached to the instances (lets them read the autosign secret)"
  value       = aws_instance.puppet_master.iam_instance_profile
}
