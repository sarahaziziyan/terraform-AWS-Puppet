locals {
  puppet_master_fqdn = "puppet.internal.puppet-server.com"
}

resource "aws_route53_zone" "internal" {
  name = "internal.puppet-server.com"

  vpc {
    vpc_id = var.vpc_id
  }
}

resource "aws_route53_record" "puppet" {
  zone_id = aws_route53_zone.internal.zone_id
  name    = local.puppet_master_fqdn
  type    = "A"
  ttl     = 60
  records = [aws_instance.puppet_master.private_ip]
}