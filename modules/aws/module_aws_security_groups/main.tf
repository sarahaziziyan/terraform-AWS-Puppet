data "aws_region" "current" {}

# AWS-managed list of the addresses EC2 Instance Connect uses in this region. AWS keeps it
# up to date, so SSH via Instance Connect works in any region without a hard-coded range.
data "aws_ec2_managed_prefix_list" "instance_connect" {
  name = "com.amazonaws.${data.aws_region.current.region}.ec2-instance-connect"
}

resource "aws_security_group" "alb" {
  name_prefix = "secg-"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  tags = {
    Name = "alb-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# AWS-managed list of the addresses CloudFront uses to reach origins.
data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

# Only CloudFront may reach the ALB, so visitors cannot bypass HTTPS by using the ALB address.
# The list counts as about 55 rules towards the group's limit of 60 inbound rules.
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from CloudFront only"
  prefix_list_id    = data.aws_ec2_managed_prefix_list.cloudfront.id
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "alb" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow all outbound traffic"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "web" {
  name_prefix = "secg-"
  description = "Web server security group for nginx instances behind ALB"
  vpc_id      = var.vpc_id

  tags = {
    Name = "web-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id            = aws_security_group.web.id
  description                  = "HTTP from ALB"
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.web.id
  description       = "SSH from EC2 Instance Connect"
  prefix_list_id    = data.aws_ec2_managed_prefix_list.instance_connect.id
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "web" {
  security_group_id = aws_security_group.web.id
  description       = "Allow all outbound traffic for package installation"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
