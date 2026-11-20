# 0005. Expose the ALB to the internet over plain HTTP

- **Status:** Superseded
- **Date:** 2026-10-17
- **Deciders:** Sarah Aziziyan
- **Supersedes:** —
- **Superseded by:** [0019](0019-cloudfront-for-https.md)
- **Commits:** `e6d3953`

## Context

The first public entry point was the ALB itself. The stack has no custom domain, so there was no name to issue a TLS certificate for.

## Decision

The ALB listened on HTTP port 80 and its security group allowed port 80 from `0.0.0.0/0`. Visitors used the ALB's DNS name.

## Considered options

- It was the simplest working setup at the time.

## Consequences

### Good

- Worked with no domain and no certificate.

### Bad

- Visitors had no encryption (known issue 10).

### Why it was superseded

[0019](0019-cloudfront-for-https.md) put CloudFront in front of the ALB to give visitors HTTPS without a domain, and restricted the ALB to CloudFront's addresses.

## Links

- [0019](0019-cloudfront-for-https.md), commit `b9962bd`
