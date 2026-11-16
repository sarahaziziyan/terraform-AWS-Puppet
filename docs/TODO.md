# TODO

Planned improvements that are not bugs. Problems with the current code are in [KNOWN_ISSUES.md](KNOWN_ISSUES.md).

## Autosign only real instances of the web ASG

**Why:** autosign trusts any certificate request that carries the shared secret. Anyone who obtains the secret, for example from a compromised web node, and can reach the master on port 8140 can enrol extra machines and receive the web nodes' Puppet configuration.

**What:** in `autosign.sh` on the master, besides checking the secret, check that the requested certname (the EC2 instance ID) is a running instance in this stack's Auto Scaling Group. Two ways:

- Ask AWS: call `autoscaling:DescribeAutoScalingInstances` (or `ec2:DescribeInstances`) for that instance ID and compare its group name. The master's instance role then needs these read-only permissions.
- Verify the instance identity document: the node adds its AWS-signed identity document to the request, and the master checks the signature, the account ID and that the instance ID equals the certname.

**Depends on:** known issue 5 (the master needs an instance role).
