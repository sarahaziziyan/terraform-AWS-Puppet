# 0012. Pass the autosign secret as a sensitive Terraform variable

- **Status:** Superseded
- **Date:** 2026-10-19
- **Deciders:** Sarah Aziziyan
- **Supersedes:** —
- **Superseded by:** [0020](0020-autosign-secret-in-ssm-via-bootstrap.md)
- **Commits:** `140f5b0`

## Context

The autosign secret ([0011](0011-autosign-with-shared-secret.md)) must reach both the master and every node.

## Decision

The secret was a root variable marked `sensitive = true`, set in `terraform.tfvars` and rendered into the user data of the master and of the launch template.

## Considered options

- `sensitive` kept it out of plan output, which was the reason given in ARCHITECTURE.md at the time.

## Consequences

### Good

- No extra AWS services or IAM roles.

### Bad

- The secret was in plain text in the state, in tfvars and in user data, readable by anyone with `ec2:DescribeInstanceAttribute` or by any process on a node through the metadata service (known issue 5).
- It was inserted into shell and YAML without escaping (known issue 11).

### Why it was superseded

[0020](0020-autosign-secret-in-ssm-via-bootstrap.md) moved the secret into an encrypted SSM parameter that is never in the plan, the state, tfvars or user data.

## Links

- [0020](0020-autosign-secret-in-ssm-via-bootstrap.md), commit `c5916be`
