# 0019. Serve visitors over HTTPS through CloudFront, without a custom domain

- **Status:** Accepted (extended by [0023](0023-secret-origin-header.md))
- **Date:** 2026-11-16
- **Deciders:** Sarah Aziziyan
- **Supersedes:** [0005](0005-alb-open-to-internet-over-http.md)
- **Superseded by:** —
- **Commits:** `b9962bd`

## Context

The site was served over plain HTTP from the ALB ([0005](0005-alb-open-to-internet-over-http.md), known issue 10). The stack has no domain, so an ACM certificate for the ALB cannot be issued.

## Decision

- A CloudFront distribution sits in front of the ALB and uses CloudFront's own certificate on `*.cloudfront.net`. HTTP is redirected to HTTPS.
- CloudFront reaches the ALB over HTTP (`origin_protocol_policy = "http-only"`), because the ALB has no certificate.
- The ALB's security group allows port 80 only from the AWS-managed prefix list `com.amazonaws.global.cloudfront.origin-facing`.
- A cache policy keeps pages for 5 minutes by default (max 1 hour) and ignores cookies, headers and query strings, so Puppet's site updates appear within minutes.

## Considered options

- **CloudFront with its default certificate**: HTTPS with no domain.
- **Custom domain with ACM certificates on CloudFront and the ALB**: the full fix, but needs a domain (the fix listed for known issue 22).

## Consequences

### Good

- Visitors use HTTPS, and the ALB's address cannot be used to bypass it.
- CloudFront caches pages, which takes load off the web nodes.

### Bad

- The site address is a generated `*.cloudfront.net` name.
- The hop from CloudFront to the ALB is plain HTTP (known issue 22).
- The CloudFront prefix list is shared by every distribution, including other AWS customers', so the security group alone does not prove a request came from this stack. [0023](0023-secret-origin-header.md) closes this.
- The prefix list counts as about 55 of the security group's 60 inbound rules.

## Links

- [modules/aws/module_aws_cloudfront/main.tf](../../modules/aws/module_aws_cloudfront/main.tf), [modules/aws/module_aws_security_groups/main.tf](../../modules/aws/module_aws_security_groups/main.tf)
