# 0018. Start nginx only from Puppet, after the site files are in place

- **Status:** Accepted
- **Date:** 2026-11-16
- **Deciders:** Sarah Aziziyan
- **Supersedes:** —
- **Superseded by:** —
- **Commits:** `b12249c`

## Context

Node user data started nginx at boot. Until the first Puppet run deployed the site, the node served the default nginx page and passed the health check. If Puppet never succeeded (`|| true`), the node stayed "healthy" with the wrong content (known issue 4).

## Decision

- User data installs nginx but does not start it.
- Puppet starts nginx only after the site files are in the web root.
- The first Puppet run is retried for up to 4 minutes (the master may still be installing on a fresh deploy). If it never succeeds, nginx stays stopped, the node fails the health check, and the ASG replaces it.
- The ASG health check grace period was raised from 180 s to 600 s to cover boot plus the first Puppet run.

## Considered options

- **Let Puppet start nginx**: health means "serves the real site".
- **A custom health check endpoint**: rejected. `/` already proves the real content is served; a separate endpoint could report healthy when the site is not.

## Consequences

### Good

- A node receives traffic only once it serves the real site; a node whose setup failed is replaced.

### Bad

- Scale-out is slower: a new node takes longer to receive traffic.
- An instance refresh waits the 600 s grace period for each batch ([0017](0017-explicit-template-version-rolling-refresh.md)).

## Links

- [modules/aws/module_aws_launch_template/user_data_nodes.tftpl](../../modules/aws/module_aws_launch_template/user_data_nodes.tftpl), [modules/aws/module_aws_asg/main.tf](../../modules/aws/module_aws_asg/main.tf)
