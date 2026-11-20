# 0003. Run web nodes in an Auto Scaling Group behind an ALB with ELB health checks

- **Status:** Accepted (scaling policy replaced by [0025](0025-target-tracking-scaling.md))
- **Date:** 2026-10-17
- **Deciders:** Sarah Aziziyan
- **Supersedes:** —
- **Superseded by:** —
- **Commits:** `e6d3953`, `6a7d8c8`

## Context

The first version of the stack created a fixed number of EC2 instances (`54af50b`). Fixed instances are not replaced when they fail, and there was no single address for visitors.

## Decision

Web nodes are launched from a launch template into an Auto Scaling Group. An Application Load Balancer sends traffic to a target group that checks `GET /` for a `200` every 30 s. The ASG uses the ELB health check (`health_check_type = "ELB"`), so a node that fails the ALB check is replaced. A CloudWatch alarm on average CPU adds one node at a time (simple scaling, 300 s cooldown).

## Considered options

- **ASG + ALB**: self-healing and one address in front of many nodes.
- **Fixed EC2 instances**: what the stack started with; no replacement, no load balancing.

## Consequences

### Good

- Nodes are disposable: an unhealthy one is replaced and traffic only reaches healthy ones.
- The fleet grows under CPU load.

### Bad

- Every node must configure itself at boot, which led to Puppet ([0008](0008-terraform-infrastructure-puppet-configuration.md)) and to autosigning ([0011](0011-autosign-with-shared-secret.md)).
- The fleet scales out but never back in, using the older simple scaling type (known issue 14).
- No ALB access logs (known issue 20).

## Links

- [modules/aws/module_aws_asg/main.tf](../../modules/aws/module_aws_asg/main.tf), [modules/aws/module_aws_alb/main.tf](../../modules/aws/module_aws_alb/main.tf)
- [KNOWN_ISSUES.md](../KNOWN_ISSUES.md)
