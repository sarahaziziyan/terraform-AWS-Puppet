output "zone_id" {
  description = "ID of the internal private hosted zone"
  value       = aws_route53_zone.internal.zone_id
}
