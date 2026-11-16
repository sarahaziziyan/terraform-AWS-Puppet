output "domain_name" {
  description = "CloudFront domain name of the site, e.g. d1234abcd.cloudfront.net"
  value       = aws_cloudfront_distribution.web.domain_name
}

output "url" {
  description = "HTTPS address of the site"
  value       = "https://${aws_cloudfront_distribution.web.domain_name}"
}

output "distribution_id" {
  description = "ID of the CloudFront distribution (for cache invalidations)"
  value       = aws_cloudfront_distribution.web.id
}

output "origin_domain_name" {
  description = "Origin the distribution forwards to (the ALB DNS name)"
  value       = one(aws_cloudfront_distribution.web.origin[*].domain_name)
}
