# 0023. Require a secret origin header between CloudFront and the ALB

- **Status:** Accepted
- **Date:** 2026-11-18
- **Deciders:** Sarah Aziziyan
- **Supersedes:** —
- **Superseded by:** —
- **Commits:** `014612e`

## Context

[0019](0019-cloudfront-for-https.md) limited the ALB to CloudFront's prefix list, but that list is shared by every CloudFront distribution, including other AWS customers'. Anyone could point their own distribution at the ALB (known issue 21).

## Decision

- Terraform generates a 40-character value (`random_password.origin_header` in `main.tf`, letters and digits only, because the ALB treats `*` and `?` as wildcards).
- The stack's distribution adds it to every request to the ALB as `X-Origin-Verify`.
- The ALB listener's default action returns `403`; a listener rule with priority 1 forwards to the target group only requests carrying the header.

## Considered options

- **Secret header checked by the ALB**: no extra cost, works with the current setup.
- **AWS WAF on the ALB**: rejected for this purpose because of cost.
- **CloudFront VPC origins with a private ALB**: considered later and rejected. It needs private subnets, and the nodes would then need a NAT gateway (about $30 or more a month).

## Consequences

### Good

- Only this stack's distribution can reach the web nodes; the HTTPS address is the only way in.

### Bad

- The header value is in the (encrypted) state and visible in the CloudFront and listener settings.
- The hop from CloudFront to the ALB is plain HTTP, so the header crosses the network unencrypted (known issue 22).
- Rotation (`terraform apply -replace=random_password.origin_header`) causes a few minutes of 403s on cache misses while CloudFront updates.

## Links

- [main.tf](../../main.tf), [modules/aws/module_aws_alb/main.tf](../../modules/aws/module_aws_alb/main.tf), [DEPLOYMENT.md](../DEPLOYMENT.md) (CloudFront origin header secret)
