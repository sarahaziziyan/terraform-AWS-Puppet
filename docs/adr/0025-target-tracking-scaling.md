# 0025. Scale the web fleet with a CPU target tracking policy

- **Status:** Accepted
- **Date:** 2026-11-20
- **Deciders:** Sarah Aziziyan
- **Supersedes:** —
- **Superseded by:** —
- **Commits:** —

## Context

[0003](0003-asg-behind-alb.md) scaled the ASG with a simple scaling policy: a CloudWatch alarm on average CPU above `cpu_threshold` added one node, with a 300 s cooldown. Nothing removed nodes, so the fleet only grew until someone lowered `asg_max_size` (known issue 14). This record changes only the scaling part of 0003; the ASG, the ALB and the health checks stay as they are.

## Decision

- The ASG module has one `TargetTrackingScaling` policy on `ASGAverageCPUUtilization`, with `target_value = var.cpu_target`. AWS creates and manages the high and low alarms itself. Scale-in stays enabled.
- `estimated_instance_warmup = 600`, the same as the health check grace period: a new node's CPU is left out of the average until boot plus the first Puppet run are done.
- The root variable `cpu_threshold` is renamed `cpu_target`, because it is now a value to hold, not a trigger. The ASG module checks that it is between 0 and 100.
- The custom `aws_cloudwatch_metric_alarm` and the simple scaling policy are removed.

## Considered options

- **Target tracking on average CPU**: one resource, scales both ways, AWS tunes the alarms.
- **Step scaling with a high and a low alarm**: more control over step sizes, but two alarms and two policies to tune by hand.
- **Keep simple scaling and add a scale-in alarm**: the smallest change, but simple scaling is the older type and waits a full cooldown between steps.

## Consequences

### Good

- The fleet shrinks again when load drops, down to `asg_min_size`, which cuts cost.
- Less code: no custom alarm or cooldown to keep in step with the policy.

### Bad

- Scale-in terminates nodes. A node in the middle of a Puppet run, or serving a slow request, can be stopped; the ALB's deregistration delay softens the second.
- New nodes still take boot plus the first Puppet run before they help, so a sharp spike is absorbed slowly.
- Existing `terraform.tfvars` files must rename `cpu_threshold` to `cpu_target`, and the value means something different: pick a target (for example 60), not a trigger.

## Links

- [modules/aws/module_aws_asg/main.tf](../../modules/aws/module_aws_asg/main.tf), [0003](0003-asg-behind-alb.md), [KNOWN_ISSUES.md](../KNOWN_ISSUES.md)
