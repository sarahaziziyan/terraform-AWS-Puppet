resource "aws_security_group" "web" {
  name_prefix = "web-sg-"
  description = "Web server managed by Ansible"
  vpc_id      = var.vpc_id

  tags = {
    Name = "web-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.web.id
  description       = "HTTP from anywhere"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}