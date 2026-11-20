# 0020. Keep the autosign secret in SSM, created by an admin-applied `bootstrap/` config

- **Status:** Accepted
- **Date:** 2026-11-16
- **Deciders:** Sarah Aziziyan
- **Supersedes:** [0012](0012-autosign-secret-as-terraform-variable.md)
- **Superseded by:** —
- **Commits:** `c5916be`

## Context

As a sensitive Terraform variable ([0012](0012-autosign-secret-as-terraform-variable.md)), the autosign secret was in plain text in the state, in tfvars and in user data (known issue 5), and was inserted into shell and YAML without escaping (known issue 11). Reading it from AWS at boot needs instance roles, but `terraform-user`, which applies the main stack, should not be able to create IAM roles.

## Decision

- A separate configuration, `bootstrap/`, is applied once by an administrator. It:
  - generates the secret as an ephemeral `random_password` (letters and digits only), never stored in the plan or the state;
  - writes it to an SSM `SecureString` parameter with the write-only `value_wo`; a new secret is written only when `autosign_secret_version` changes;
  - creates one role and instance profile each for the master and the web nodes, whose only permission is `ssm:GetParameter` on that parameter;
  - lets `terraform-user` pass only these two roles, and only to EC2 (`iam:PassRole` with `iam:PassedToService`).
- The main stack refers to the parameter and the instance profiles by name only.
- The master's `autosign.sh` reads the secret from SSM for each request and never stores it. A node reads it at boot, writes it into `csr_attributes.yaml`, and deletes that file after the first Puppet run.

## Considered options

- **SSM Parameter Store, ephemeral + write-only**: the secret never reaches state, plan, tfvars or user data.
- **Secrets Manager**: also listed as a fix for known issue 5; rejected on cost and simplicity.
- **Keep the sensitive variable** ([0012](0012-autosign-secret-as-terraform-variable.md)): secret in plain text in several places.

## Consequences

### Good

- The secret is only in the encrypted parameter, and briefly on each node until its first Puppet run.
- Rotation is one admin apply; the master picks up the new secret immediately and enrolled nodes keep working.
- `terraform-user` never creates IAM roles.

### Bad

- Two configurations to apply, in order, with different credentials.
- Moving an existing stack needed a one-off replacement of the master ([DEPLOYMENT.md](../DEPLOYMENT.md)).
- Any process on a node can still read the secret through the node's role. Checking that each request comes from a real ASG instance is in [TODO.md](../TODO.md).

## Links

- [bootstrap/main.tf](../../bootstrap/main.tf), [INTERFACES.md](../INTERFACES.md) (bootstrap interface), [DEPLOYMENT.md](../DEPLOYMENT.md) (autosign secret)
