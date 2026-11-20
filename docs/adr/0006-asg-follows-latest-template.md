# 0006. ASG uses the `$Latest` launch template version

- **Status:** Superseded
- **Date:** 2026-10-16
- **Deciders:** Sarah Aziziyan
- **Supersedes:** —
- **Superseded by:** [0017](0017-explicit-template-version-rolling-refresh.md)
- **Commits:** `752aa4b`, `e6d3953`

## Context

The ASG needs to know which version of the web launch template to launch.

## Decision

The ASG's `launch_template` block used `version = "$Latest"`.

## Considered options

- `$Latest` is the common default and needs no wiring.

## Consequences

### Good

- New instances always used the newest template without changing the ASG.

### Bad

- The ASG resource itself never changed when the template did, so Terraform had nothing to update and running nodes kept the old configuration until they happened to be replaced (known issue 2).

### Why it was superseded

[0017](0017-explicit-template-version-rolling-refresh.md) passes the template's explicit version number, so a template change becomes an ASG change and starts a rolling instance refresh.

## Links

- [0017](0017-explicit-template-version-rolling-refresh.md), commit `4c34448`
