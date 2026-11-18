# HTTPS in front of the load balancer, without a custom domain.
# Visitors use https://<id>.cloudfront.net with CloudFront's own certificate; plain HTTP is
# redirected to HTTPS. CloudFront reaches the ALB over HTTP, because the ALB has no certificate.
# Every request to the ALB carries a secret header, so the ALB can tell this distribution
# apart from other CloudFront distributions.

# Short cache: Puppet redeploys the site every 30 minutes, so a short TTL keeps content fresh
# while still taking load off the web nodes.
resource "aws_cloudfront_cache_policy" "site" {
  name        = "web-site-5min"
  comment     = "Static site: cache 5 minutes, ignore cookies, headers and query strings"
  default_ttl = 300
  max_ttl     = 3600
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true

    cookies_config {
      cookie_behavior = "none"
    }
    headers_config {
      header_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "none"
    }
  }
}

resource "aws_cloudfront_distribution" "web" {
  enabled         = true
  comment         = "HTTPS front for the web ALB"
  is_ipv6_enabled = true
  http_version    = "http2and3"
  price_class     = "PriceClass_All"

  origin {
    origin_id   = "alb"
    domain_name = var.alb_dns_name

    # Added to every request sent to the ALB; never sent to visitors.
    custom_header {
      name  = var.origin_header_name
      value = var.origin_header_value
    }

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id       = "alb"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = aws_cloudfront_cache_policy.site.id
    compress               = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "web-cdn"
  }
}
