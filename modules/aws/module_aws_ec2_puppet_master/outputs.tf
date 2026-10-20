output "private_ip" {
  description = "Private IP of the Puppet master"
  value       = aws_instance.puppet_master.private_ip
}
