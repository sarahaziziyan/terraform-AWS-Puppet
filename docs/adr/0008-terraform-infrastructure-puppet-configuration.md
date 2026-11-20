# 0008. Terraform for infrastructure, Puppet for configuration and site deployment

- **Status:** Accepted
- **Date:** 2026-10-19
- **Deciders:** Sarah Aziziyan
- **Supersedes:** [0007](0007-serve-site-from-user-data.md)
- **Superseded by:** —
- **Commits:** `e77e076`, `140f5b0`, `9e17701`

## Context

With the site deployed from user data ([0007](0007-serve-site-from-user-data.md)), running nodes never picked up changes to the site repository, and every configuration change meant new user data and new nodes.

## Decision

- Terraform creates the cloud resources.
- A dedicated Puppet master (Ubuntu 22.04) configures the web nodes. Each node runs a Puppet agent that checks in every 30 minutes.
- The master's `profile::website` class uses the `vcsrepo` module to clone the site repository and copy `index.html` and assets into the nginx web root.
- The site repository URL and branch come from `terraform.tfvars` and are written on each node as Puppet facts (`/etc/puppetlabs/facter/facts.d/site.txt`), so the Puppet code stays generic.

## Considered options

- **Terraform + Puppet**: each tool does what it is best at; content changes need no Terraform run.
- **Keep deploying from user data** ([0007](0007-serve-site-from-user-data.md)): no master to run, but no updates to running nodes.
- **Ansible**: considered first, but we chose Puppet's agent-based pull model over Ansible's push model, which needs a central runner.

## Consequences

### Good

- Pushing to the site branch updates every node within 30 minutes, with no Terraform run.
- One source of truth for the repository and branch: `terraform.tfvars`.

### Bad

- A single Puppet master with no HA and no CA backup (known issue 17). If it is down, running nodes keep serving but new ones cannot finish setup.
- Nodes need to find and trust the master, which led to [0009](0009-private-dns-for-puppet-master.md), [0010](0010-instance-id-as-certname.md) and [0011](0011-autosign-with-shared-secret.md).
- The Puppet code is embedded in the master's bootstrap script and does not reach the master through Terraform (known issue 16).
- Puppet packages come from the public repositories, unpinned (known issue 12).
- The website must be a public repository.

## Links

- [ARCHITECTURE.md](../ARCHITECTURE.md) (data and control flow), [INTERFACES.md](../INTERFACES.md) (Puppet interface)
- [modules/aws/module_aws_launch_template/user_data_nodes.tftpl](../../modules/aws/module_aws_launch_template/user_data_nodes.tftpl)
