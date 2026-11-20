# 0013. Allow SSH from a hard-coded EC2 Instance Connect range

- **Status:** Superseded
- **Date:** 2026-10-17
- **Deciders:** Sarah Aziziyan
- **Supersedes:** —
- **Superseded by:** [0021](0021-ssh-through-instance-connect-prefix-list.md)
- **Commits:** `6a7d8c8`

## Context

Operators need SSH to the web nodes and the master for debugging, without opening port 22 to the internet.

## Decision

SSH (22) was allowed only from `3.0.5.32/29`, the EC2 Instance Connect range for `ap-southeast-1`.

## Considered options

- This was the Instance Connect range for ap-southeast-1, where the stack was built. It was the simplest rule that worked, and no alternatives were considered.

## Consequences

### Good

- SSH limited to EC2 Instance Connect.

### Bad

- The range is correct only in `ap-southeast-1`; in any other region SSH would not work (known issue 8).

### Why it was superseded

[0021](0021-ssh-through-instance-connect-prefix-list.md) uses the region's AWS-managed prefix list instead.

## Links

- [0021](0021-ssh-through-instance-connect-prefix-list.md), commit `00a82e8`
