# Unit tests for module_aws_dns.
# Self-contained: the AWS provider is mocked, so no credentials or real resources are needed.
# Run from this module's folder:  terraform init && terraform test

mock_provider "aws" {}

variables {
  vpc_id                   = "vpc-0123456789abcdef0"
  puppet_master_fqdn       = "puppet.internal.puppet-server.com"
  puppet_master_private_ip = "10.0.1.25"
}

# The zone must be private (attached to the VPC), so the name never resolves publicly.
run "zone_is_private_to_the_vpc" {
  command = apply

  assert {
    condition     = aws_route53_zone.internal.name == "internal.puppet-server.com"
    error_message = "The hosted zone must be internal.puppet-server.com."
  }

  assert {
    condition     = length(aws_route53_zone.internal.vpc) == 1
    error_message = "The zone must be associated with exactly one VPC, which makes it a private zone."
  }

  assert {
    condition     = alltrue([for v in aws_route53_zone.internal.vpc : v.vpc_id == var.vpc_id])
    error_message = "The zone must be associated with the VPC passed to the module."
  }
}

# Web nodes find the Puppet master only through this record.
run "record_points_fqdn_at_master_ip" {
  command = apply

  assert {
    condition     = aws_route53_record.puppet.zone_id == aws_route53_zone.internal.zone_id
    error_message = "The record must be created in the internal zone."
  }

  assert {
    condition     = aws_route53_record.puppet.name == var.puppet_master_fqdn
    error_message = "The record name must be the Puppet master FQDN."
  }

  assert {
    condition     = aws_route53_record.puppet.type == "A"
    error_message = "The record must be an A record."
  }

  assert {
    condition     = aws_route53_record.puppet.records == toset([var.puppet_master_private_ip])
    error_message = "The record must point only at the Puppet master's private IP."
  }

  assert {
    condition     = aws_route53_record.puppet.ttl == 60
    error_message = "The TTL must be 60 seconds so a replaced master is picked up quickly."
  }
}

# The FQDN passed in must belong to the zone, otherwise the record is created but never resolves.
run "fqdn_belongs_to_the_zone" {
  command = apply

  assert {
    condition     = endswith(aws_route53_record.puppet.name, ".${aws_route53_zone.internal.name}")
    error_message = "The Puppet master FQDN must be inside the internal zone."
  }
}

run "output_exposes_zone_id" {
  command = apply

  assert {
    condition     = output.zone_id == aws_route53_zone.internal.zone_id
    error_message = "zone_id must be the internal zone's ID."
  }
}
