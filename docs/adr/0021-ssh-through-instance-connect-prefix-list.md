# 0021. Allow SSH only through the region's EC2 Instance Connect prefix list

- **Status:** Accepted
- **Date:** 2026-11-17
- **Deciders:** Sarah Aziziyan
- **Supersedes:** [0013](0013-ssh-from-hard-coded-instance-connect-range.md)
- **Superseded by:** —
- **Commits:** `00a82e8`

## Context

The hard-coded range `3.0.5.32/29` ([0013](0013-ssh-from-hard-coded-instance-connect-range.md)) is correct only in `ap-southeast-1` (known issue 8).

## Decision

Both SSH rules (web nodes and master) use the AWS-managed prefix list `com.amazonaws.<region>.ec2-instance-connect`, looked up for the current region.

## Considered options

- **AWS-managed prefix list**: correct in any region and kept up to date by AWS.
- **A region-to-CIDR map in Terraform**: would need manual updates.
- **SSM Session Manager instead of SSH**: Not considered at the time; a better option

## Consequences

### Good

- SSH via EC2 Instance Connect works in any region, with no hard-coded addresses.

### Bad

- Port 22 is still open to the Instance Connect service range.

## Links

- [modules/aws/module_aws_security_groups/main.tf](../../modules/aws/module_aws_security_groups/main.tf)
