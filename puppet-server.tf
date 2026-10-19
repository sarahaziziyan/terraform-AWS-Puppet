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
  referenced_security_group_id = aws_security_group.web.id
  ip_protocol                  = "tcp"
  from_port                    = 8140
  to_port                      = 8140
}

resource "aws_vpc_security_group_ingress_rule" "puppet_master_ssh" {
  security_group_id = aws_security_group.puppet_master.id
  description       = "SSH from admin IP"
  cidr_ipv4         = var.admin_ssh_cidr
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
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

  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail
    cd /tmp
    wget https://apt.puppet.com/puppet8-release-jammy.deb
    dpkg -i puppet8-release-jammy.deb
    apt-get update
    apt-get install -y puppetserver

    # Set names BEFORE first start (the CA and server certs are created then)
    /opt/puppetlabs/bin/puppet config set certname ${local.puppet_master_fqdn} --section main
    /opt/puppetlabs/bin/puppet config set server ${local.puppet_master_fqdn} --section main
    /opt/puppetlabs/bin/puppet config set dns_alt_names puppet,${local.puppet_master_fqdn} --section server

    # Reduce JVM heap if you use a small instance (default is 2g)
    sed -i 's/-Xms2g -Xmx2g/-Xms1g -Xmx1g/' /etc/default/puppetserver

    systemctl enable --now puppetserver
  EOF

  tags = { Name = "puppet-master" }
}

output "puppet_master_private_ip" {
  value = aws_instance.puppet_master.private_ip
}