# 0014. Split the stack into reusable modules, one per concern

- **Status:** Accepted (extended by [0024](0024-puppet-server-module-own-repository.md))
- **Date:** 2026-10-20
- **Deciders:** Sarah Aziziyan
- **Supersedes:** —
- **Superseded by:** —
- **Commits:** `57d7f06`, `484cc1d`, `ca6fd7c`

## Context

All resources were in flat root files (`alb.tf`, `asg.tf`, `dns.tf`, …). Inputs and outputs between the parts were implicit, and no part could be tested alone.

## Decision

Each concern is a module under `modules/aws/` (security groups, DNS, launch template, ALB, CloudFront, ASG), with `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf` and a `tests/` folder. A module refers to nothing outside its own folder, so it can move to its own repository. The root `main.tf` only wires modules together, and calls them by their role in the stack (`security_groups`, `puppet_server`, `internal_dns`, `web_launch_template`, `alb`, `cdn`, `web_asg`).

## Considered options

- **One module per concern**: small units with explicit interfaces that can be tested with mock providers.
- **Flat root configuration**: what the stack started with.

## Consequences

### Good

- Root `main.tf` reads as a table of contents.
- Each module has unit tests that run without AWS credentials ([TESTING.md](../TESTING.md)).
- Modules can be moved to their own repositories ([0024](0024-puppet-server-module-own-repository.md)).

### Bad

- Renaming a module call in `main.tf` needs `moved` blocks, or Terraform plans to replace its resources.
- The root wiring test cannot see inside modules, so it does not check that the same FQDN reaches the master, the DNS record and the nodes.

## Links

- [ARCHITECTURE.md](../ARCHITECTURE.md) (folder structure), [INTERFACES.md](../INTERFACES.md)
