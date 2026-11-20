# 0002. Store Terraform state in an S3 remote backend

- **Status:** Accepted (extended by [0022](0022-encrypt-and-lock-state.md))
- **Date:** 2026-10-05
- **Deciders:** Sarah Aziziyan
- **Supersedes:** —
- **Superseded by:** —
- **Commits:** `7b0f80c`, `54af50b`

## Context

Terraform keeps a state file that maps the configuration to real AWS resources. A local state file is lost with the laptop and cannot be shared.

## Decision

The root stack uses the `s3` backend (bucket `backend-terraform-online-app`, region `ap-southeast-1`), configured in [provider.tf](../../provider.tf). The `bootstrap/` configuration uses the same bucket with its own key.

## Considered options

- **S3 backend**: durable, shared, and in the same AWS account as the stack.
- **Local state**: the default; not durable and not shareable.
- **Terraform Cloud**: initially s3 was picked, but later we might move to Terraform Cloud.

## Consequences

### Good

- State survives the machine that ran Terraform and can be used from anywhere with access to the bucket.

### Bad

- The bucket must exist before the first `terraform init`; it is not created by this stack.
- State holds sensitive values (for example the CloudFront origin header), so access to the bucket must be restricted.
- At first there was no locking or explicit encryption (known issue 9). [0022](0022-encrypt-and-lock-state.md) added both.

## Links

- [provider.tf](../../provider.tf), [bootstrap/versions.tf](../../bootstrap/versions.tf)
- [DEPLOYMENT.md](../DEPLOYMENT.md)
