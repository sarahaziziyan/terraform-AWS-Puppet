# 0024. Move the Puppet server module to its own versioned repository

- **Status:** Accepted
- **Date:** 2026-11-20
- **Deciders:** Sarah Aziziyan
- **Supersedes:** —
- **Superseded by:** —
- **Commits:** `3f8cf9a`, `ca6fd7c`

## Context

Modules were designed to move to their own repositories ([0014](0014-one-module-per-concern.md)). The Puppet master module holds the most sensitive piece of the stack (the CA) and its own bootstrap script, and is the one whose changes most need to be reviewed and released on purpose.

## Decision

The Puppet server module (instance, its security group and bootstrap script) lives in [terraform-aws-puppet-server](https://github.com/sarahaziziyan/terraform-aws-puppet-server). It is versioned with `vX.Y.Z` tags created by release-please, and `main.tf` pins it with `?ref=v1.0.0` under the name `puppet_server`. The other modules stay under `modules/aws/` until they move.

## Considered options

- **Separate repository with tagged releases**: upgrades are explicit and reviewable.
- **Keep it in this repository**: simpler, but changes ship with every commit.

## Consequences

### Good

- Upgrading the master is a deliberate change of `?ref=`, followed by `terraform init` and a plan review.
- The module has its own tests and release history.

### Bad

- Changes now span two repositories.
- Renaming the module call needs a `moved` block, or Terraform plans to replace the master.
- Known issues 16 and 17 are now fixed in the other repository.

## Links

- [main.tf](../../main.tf), [ARCHITECTURE.md](../ARCHITECTURE.md) (folder structure)
