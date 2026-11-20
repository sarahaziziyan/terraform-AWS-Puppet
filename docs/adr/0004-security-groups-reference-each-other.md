# 0004. Security groups reference each other instead of IP ranges

- **Status:** Accepted
- **Date:** 2026-10-17
- **Deciders:** Sarah Aziziyan
- **Supersedes:** —
- **Superseded by:** —
- **Commits:** `6a7d8c8`, `e77e076`

## Context

Web nodes and the Puppet master get new private IPs whenever they are replaced, so rules based on IP ranges would either be too wide or go out of date.

## Decision

Rules name the source security group (`referenced_security_group_id`):

- Web nodes accept HTTP (80) only from the ALB's security group.
- The Puppet master accepts Puppet (8140) only from the web nodes' security group.

SSH is handled separately ([0013](0013-ssh-from-hard-coded-instance-connect-range.md), then [0021](0021-ssh-through-instance-connect-prefix-list.md)), and the ALB's own inbound rule by [0005](0005-alb-open-to-internet-over-http.md), then [0019](0019-cloudfront-for-https.md).

## Considered options

- **Security group references**: follow the instances automatically.
- **CIDR ranges (for example the VPC range)**: simpler, but let in anything in the range.

## Consequences

### Good

- Least-privilege network paths that stay correct when instances are replaced.

### Bad

- The web security group ID is passed to the Puppet server module, which now lives in another repository ([0024](0024-puppet-server-module-own-repository.md)), so the two must stay compatible.

## Links

- [modules/aws/module_aws_security_groups/main.tf](../../modules/aws/module_aws_security_groups/main.tf)
