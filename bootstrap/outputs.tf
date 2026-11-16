output "autosign_secret_parameter_name" {
  description = "SSM parameter holding the autosign secret (the main stack's autosign_secret_parameter_name)"
  value       = aws_ssm_parameter.autosign_secret.name
}

output "puppet_master_instance_profile_name" {
  description = "Instance profile for the Puppet master (the main stack's puppet_master_instance_profile_name)"
  value       = aws_iam_instance_profile.instance["puppet_master"].name
}

output "web_node_instance_profile_name" {
  description = "Instance profile for the web nodes (the main stack's web_node_instance_profile_name)"
  value       = aws_iam_instance_profile.instance["web_node"].name
}
