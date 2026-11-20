# 0016. Require IMDSv2 and encrypt root volumes explicitly

- **Status:** Accepted
- **Date:** 2026-11-11 (IMDSv2); 2026-11-13 (encryption)
- **Deciders:** Sarah Aziziyan
- **Supersedes:** —
- **Superseded by:** —
- **Commits:** `4bb369e`, `523f56e`

## Context

- IMDSv1 answers plain GET requests, so an SSRF bug in anything on the instance could read user data and role credentials (known issue 6).
- Root volumes were encrypted only if the account's default said so. The master's volume holds the Puppet CA key (known issue 7).

## Decision

- The master and the web launch template set `http_tokens = "required"` with `http_put_response_hop_limit = 1`.
- The master's root volume and the launch template's root volume set `encrypted = true`, using the AWS-managed EBS key.

## Considered options

- **Set both explicitly in Terraform**: correct whatever the account defaults are.
- **Rely on account-level defaults**: not visible in the code, and differ between accounts.

## Consequences

### Good

- A plain GET to the metadata service cannot read user data or credentials.
- Disks are encrypted in every account.

### Bad

- Any process already running on the instance can still get a token, so IMDSv2 does not protect against code running there.
- The bootstrap scripts must use the IMDSv2 token flow to read the instance ID.

## Links

- [ARCHITECTURE.md](../ARCHITECTURE.md) (security notes), [modules/aws/module_aws_launch_template/main.tf](../../modules/aws/module_aws_launch_template/main.tf)
