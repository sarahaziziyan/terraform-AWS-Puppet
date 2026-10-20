data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_security_group" "puppet_master" {
  name   = "puppet-master"
  vpc_id = var.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "puppet_master_puppet" {
  security_group_id            = aws_security_group.puppet_master.id
  description                  = "Puppet agent traffic from web nodes"
  referenced_security_group_id = var.web_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 8140
  to_port                      = 8140
}

resource "aws_vpc_security_group_ingress_rule" "puppet_master_instance_connect" {
  security_group_id = aws_security_group.puppet_master.id
  description       = "SSH from EC2 Instance Connect"
  cidr_ipv4         = "3.0.5.32/29"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "puppet_master" {
  security_group_id = aws_security_group.puppet_master.id
  description       = "Allow all outbound traffic"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_instance" "puppet_master" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.medium"
  subnet_id              = var.subnet_id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.puppet_master.id]

  root_block_device { volume_size = 30 }

  user_data = templatefile("${path.module}/puppet_master.tftpl", {
    puppet_master_fqdn     = var.puppet_master_fqdn
    puppet_autosign_secret = var.puppet_autosign_secret
  })

  lifecycle {
    ignore_changes = [user_data]
  }
  tags = { Name = "puppet-master" }
}
