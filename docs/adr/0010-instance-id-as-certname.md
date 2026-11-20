# 0010. Use the EC2 instance ID as the Puppet certname

- **Status:** Accepted
- **Date:** 2026-10-19
- **Deciders:** Sarah Aziziyan
- **Supersedes:** —
- **Superseded by:** —
- **Commits:** `140f5b0`

## Context

Each Puppet agent needs a unique certificate name. ASG nodes come and go, and a replacement may get the same private IP or hostname as an old node whose certificate is still on the master.

## Decision

At boot, each node sets `certname` to its EC2 instance ID (`i-xxxx…`), read from the instance metadata service. The master's `site.pp` matches nodes named `i-…`.

## Considered options

- **Instance ID**: unique per instance and known at boot.
- **Hostname or private DNS name**: can be reused by a later instance and clash with an old certificate.

## Consequences

### Good

- Replaced nodes never clash with old certificates.
- The certname can later be checked against the ASG's real members (planned in [TODO.md](../TODO.md)).

### Bad

- Certificates of terminated nodes stay on the master; nothing cleans them up.
- Accepted risk: tracked with the TODO.md autosign work.

## Links

- [modules/aws/module_aws_launch_template/user_data_nodes.tftpl](../../modules/aws/module_aws_launch_template/user_data_nodes.tftpl)
