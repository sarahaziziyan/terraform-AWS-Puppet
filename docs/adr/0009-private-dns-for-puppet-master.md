# 0009. Find the Puppet master through a private Route 53 zone

- **Status:** Accepted
- **Date:** 2026-10-19
- **Deciders:** Sarah Aziziyan
- **Supersedes:** —
- **Superseded by:** —
- **Commits:** `e77e076`

## Context

Agents must reach the master by a name that also matches the master's certificate. The master's private IP changes when it is replaced.

## Decision

A private Route 53 zone `internal.puppet-server.com`, attached to the VPC, holds an A record `puppet.internal.puppet-server.com` pointing at the master's private IP. The same FQDN is the master's certname and DNS alt name and the `server` setting on every agent.

## Considered options

- **Private DNS name**: stable across master replacement.
- **Pass the master's IP to nodes**: simpler, but every node's configuration would have to change when the master is replaced.

## Consequences

### Good

- The master can be replaced without editing node configuration; Terraform updates the record.

### Bad

- The domain is hard-coded in two places that must agree: the FQDN in the root `main.tf` and the zone name in the DNS module (known issue 15).

## Links

- [modules/aws/module_aws_dns/main.tf](../../modules/aws/module_aws_dns/main.tf), [main.tf](../../main.tf)
