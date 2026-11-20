# 0017. Use the explicit launch template version and a rolling instance refresh

- **Status:** Accepted
- **Date:** 2026-11-16
- **Deciders:** Sarah Aziziyan
- **Supersedes:** [0006](0006-asg-follows-latest-template.md)
- **Superseded by:** —
- **Commits:** `4c34448`

## Context

With `$Latest` ([0006](0006-asg-follows-latest-template.md)), a launch template change did not change the ASG resource, so running nodes kept the old configuration (known issue 2).

## Decision

The launch template module outputs `latest_version`, and the ASG uses that number as its `launch_template.version`. The ASG has an `instance_refresh` block with the `Rolling` strategy and `min_healthy_percentage = 50`. When the template changes, the version number changes, Terraform updates the ASG, and the refresh replaces running nodes in batches.

## Considered options

- **Explicit version + `instance_refresh`**: changes roll out on apply, without downtime.
- **`$Latest`** ([0006](0006-asg-follows-latest-template.md)): no rollout to running nodes.
- **Replace the whole ASG on change** (`create_before_destroy` with a new name): considered but not selected.

## Consequences

### Good

- Template changes reach every running node on the next apply, keeping at least half the fleet healthy.

### Bad

- The template looks up the newest Amazon Linux 2023 image, so a new image release also starts a refresh on the next apply.
- Each batch waits for the 600 s health check grace period ([0018](0018-nginx-started-only-by-puppet.md)), so a refresh is slow.

## Links

- [modules/aws/module_aws_asg/main.tf](../../modules/aws/module_aws_asg/main.tf), [DEPLOYMENT.md](../DEPLOYMENT.md) (updating)
