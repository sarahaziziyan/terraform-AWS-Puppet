# 0022. Encrypt and lock Terraform state in both backends

- **Status:** Accepted
- **Date:** 2026-11-18
- **Deciders:** Sarah Aziziyan
- **Supersedes:** —
- **Superseded by:** —
- **Commits:** `4120fd7`

## Context

The S3 backend ([0002](0002-s3-remote-backend.md)) had no state locking and did not request encryption explicitly (known issue 9). Two applies at once could overwrite each other's state.

## Decision

Both backends ([provider.tf](../../provider.tf) and [bootstrap/versions.tf](../../bootstrap/versions.tf)) set `encrypt = true` and `use_lockfile = true`. Terraform holds a `<state key>.tflock` object in the bucket during `plan` and `apply`. The required Terraform version is raised to `>= 1.10`, the first release with S3 native locking.

## Considered options

- **S3 native lock file**: no extra resources.
- **DynamoDB lock table**: the older method, needs a table; deprecated by Terraform in favour of the lock file.

## Consequences

### Good

- A second run stops with "Error acquiring the state lock" instead of overwriting state.
- State is always written with server-side encryption.

### Bad

- Terraform 1.10 or newer is required.
- The identity running Terraform also needs `s3:GetObject`, `s3:PutObject` and `s3:DeleteObject` on the `.tflock` object.
- A killed run can leave the lock behind; it must be released with `terraform force-unlock`.

## Links

- [DEPLOYMENT.md](../DEPLOYMENT.md) (state locking and encryption)
