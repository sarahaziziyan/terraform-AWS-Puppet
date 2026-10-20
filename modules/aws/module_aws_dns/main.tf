resource "aws_route53_zone" "internal" {
  name = "internal.puppet-server.com"

  vpc {
    vpc_id = var.vpc_id
  }
}

resource "aws_route53_record" "puppet" {
  zone_id = aws_route53_zone.internal.zone_id
  name    = var.puppet_master_fqdn
  type    = "A"
  ttl     = 60
  records = [var.puppet_master_private_ip]
}
