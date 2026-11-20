# 0007. Deploy the website from EC2 user data

- **Status:** Superseded
- **Date:** 2026-10-18
- **Deciders:** Sarah Aziziyan
- **Supersedes:** —
- **Superseded by:** [0008](0008-terraform-infrastructure-puppet-configuration.md)
- **Commits:** `a880d3a`

## Context

Each new node in the ASG ([0003](0003-asg-behind-alb.md)) must serve the website. The site lives in a public Git repository.

## Decision

The launch template's user data script installed nginx and git, cloned the site repository (`site_repo_url`, `site_repo_branch`), copied the files into the nginx web root, then started and enabled nginx.

## Considered options

- User data was the first step before Puppet was added the next day.

## Consequences

### Good

- Simple, no other server needed.

### Bad

- The site was copied once at boot. A change to the repository reached only nodes launched afterwards.
- A change to the configuration meant changing user data and replacing nodes.

### Why it was superseded

[0008](0008-terraform-infrastructure-puppet-configuration.md) moved configuration and site deployment to Puppet, which keeps every node in step with the repository.

## Links

- [0008](0008-terraform-infrastructure-puppet-configuration.md)
