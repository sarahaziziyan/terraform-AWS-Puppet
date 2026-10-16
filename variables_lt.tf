variable "key_name" {
  type        = string
  description = "Name of an existing EC2 key pair"
  default     = "ec2-keypair"
}

variable "vpc_id" {
  type        = string
  description = "VPC where the security group is created"
}

variable "subnet_id" {
  type        = string
  description = "Subnet to launch the instance in"
}
