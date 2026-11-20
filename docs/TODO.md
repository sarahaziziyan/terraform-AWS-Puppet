# TODO

Planned improvements that are not bugs. Problems with the current code are in [KNOWN_ISSUES.md](KNOWN_ISSUES.md).

## Autosign only real instances of the web ASG

**Why:** autosign trusts any certificate request that carries the shared secret. Anyone who obtains the secret, for example from a compromised web node, and can reach the master on port 8140 can enrol extra machines and receive the web nodes' Puppet configuration.

**What:** in `autosign.sh` on the master, besides checking the secret, check that the requested certname (the EC2 instance ID) is a running instance in this stack's Auto Scaling Group. Two ways:

- Ask AWS: call `autoscaling:DescribeAutoScalingInstances` (or `ec2:DescribeInstances`) for that instance ID and compare its group name. The master's instance role then needs these read-only permissions.
- Verify the instance identity document: the node adds its AWS-signed identity document to the request, and the master checks the signature, the account ID and that the instance ID equals the certname.

**Depends on:** nothing. The master already has an instance role, created by `bootstrap/`; for the first way, add the read-only permissions to that role in `bootstrap/main.tf`.

## Clean up certificates of terminated web servers

**Why:** each web server gets a Puppet certificate named after its instance ID ([ADR 0010](adr/0010-instance-id-as-certname.md)), and nothing removes it when the server is terminated. With the working-hours schedule ([ADR 0026](adr/0026-working-hours-schedule.md)) a new set of servers starts every working day, so old certificates pile up on the master faster. Harmless, but untidy, and the CA's list of signed certificates grows without limit.

**What:** remove the certificates of instances that no longer exist, for example a daily job on the master that runs `puppetserver ca list --all`, keeps the `i-…` names that are not running instances (`ec2:DescribeInstances`), and runs `puppetserver ca clean --certname <id>` for each. An ASG lifecycle hook on termination would be quicker but needs more moving parts.

**Depends on:** read-only `ec2:DescribeInstances` for the master's instance role (`bootstrap/main.tf`), and a change to the master's bootstrap in the terraform-aws-puppet-server repository.
