# Unit tests for module_aws_cloudfront.
# Self-contained: the AWS provider is mocked, so no credentials or real resources are needed.
# Run from this module's folder:  terraform init && terraform test

mock_provider "aws" {
  mock_resource "aws_cloudfront_distribution" {
    defaults = {
      domain_name = "d1234abcd.cloudfront.net"
    }
  }
}

variables {
  alb_dns_name = "alb-test-123456789.ap-southeast-1.elb.amazonaws.com"
}

# Known issue 10: visitors must get HTTPS. Plain HTTP is redirected, not served.
run "viewers_are_redirected_to_https" {
  command = apply

  assert {
    condition     = aws_cloudfront_distribution.web.default_cache_behavior[0].viewer_protocol_policy == "redirect-to-https"
    error_message = "Viewers must be redirected from HTTP to HTTPS."
  }

  assert {
    condition     = aws_cloudfront_distribution.web.viewer_certificate[0].cloudfront_default_certificate == true
    error_message = "Without a custom domain, the distribution must use CloudFront's default certificate."
  }

  assert {
    condition     = output.url == "https://d1234abcd.cloudfront.net"
    error_message = "url must be the HTTPS address of the distribution."
  }
}

# CloudFront must forward to the ALB over HTTP: the ALB has no certificate, so HTTPS to it would fail.
run "origin_is_the_alb_over_http" {
  command = apply

  assert {
    condition     = output.origin_domain_name == var.alb_dns_name
    error_message = "The origin must be the ALB DNS name passed to the module."
  }

  assert {
    condition = anytrue([
      for o in aws_cloudfront_distribution.web.origin :
      o.custom_origin_config[0].origin_protocol_policy == "http-only" && o.custom_origin_config[0].http_port == 80
    ])
    error_message = "CloudFront must reach the ALB with HTTP on port 80."
  }

  assert {
    condition     = aws_cloudfront_distribution.web.default_cache_behavior[0].target_origin_id == "alb"
    error_message = "The default behaviour must use the ALB origin."
  }
}

# The site is static and read-only, and Puppet updates it every 30 minutes.
run "caching_suits_a_static_site" {
  command = apply

  assert {
    condition     = toset(aws_cloudfront_distribution.web.default_cache_behavior[0].allowed_methods) == toset(["GET", "HEAD"])
    error_message = "Only GET and HEAD may be allowed; the site has no forms or APIs."
  }

  assert {
    condition     = aws_cloudfront_distribution.web.default_cache_behavior[0].cache_policy_id == aws_cloudfront_cache_policy.site.id
    error_message = "The default behaviour must use the module's cache policy."
  }

  assert {
    condition     = aws_cloudfront_cache_policy.site.default_ttl == 300 && aws_cloudfront_cache_policy.site.max_ttl == 3600
    error_message = "Pages must be cached for 5 minutes by default (1 hour at most), so site updates appear quickly."
  }

  assert {
    condition     = aws_cloudfront_distribution.web.default_cache_behavior[0].compress == true
    error_message = "Compression must be enabled."
  }
}
