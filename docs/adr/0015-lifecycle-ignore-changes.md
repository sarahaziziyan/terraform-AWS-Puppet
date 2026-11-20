# 0015. Ignore selected changes on the Puppet master and the ASG

- **Status:** Accepted (extended by [0026](0026-working-hours-schedule.md): the ASG also ignores `min_size`)
- **Date:** 2026-10-19 (master `user_data`); extended 2026-11-10 (master `ami`, ASG `desired_capacity`)
- **Deciders:** Sarah Aziziyan
- **Supersedes:** —
- **Superseded by:** —
- **Commits:** `9e17701`, `66defed`, `fcbb6ca`

## Context

- The Puppet master holds the Puppet CA. A change to its user data or to its AMI (the Ubuntu image lookup returns the newest image) makes Terraform replace the instance, which destroys the CA and every node certificate (known issue 1).
- The scaling policy changes the ASG's `desired_capacity` at runtime. Every `terraform apply` reset it to `asg_desired_capacity` and undid scale-out (known issue 3).

## Decision

- The master has `lifecycle { ignore_changes = [user_data, ami] }`.
- The ASG has `lifecycle { ignore_changes = [desired_capacity] }`. `asg_desired_capacity` is only the size when the ASG is created.

## Considered options

- **`ignore_changes`**: keeps the running master and the current fleet size.
- **Pin the AMI ID**: keeps the master, but a bootstrap script edit would still replace it.

## Consequences

### Good

- An apply never rebuilds the master by accident, and never shrinks a scaled-out fleet.

### Bad

- Changes to the master's Puppet code never reach the running master through Terraform (known issue 16). Replacing the master is a deliberate, documented procedure ([DEPLOYMENT.md](../DEPLOYMENT.md)).
- The master keeps an old Ubuntu image until it is replaced on purpose.

## Links

- [modules/aws/module_aws_asg/main.tf](../../modules/aws/module_aws_asg/main.tf); the master's lifecycle is in the terraform-aws-puppet-server repository ([0024](0024-puppet-server-module-own-repository.md))
