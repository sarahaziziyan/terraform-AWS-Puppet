# Known issues

Open problems found by reviewing the code. Items marked **(verify)** are likely but were not confirmed on a real deployment. Issue numbers are stable: a fixed issue is removed and its number is not reused.

Fixed so far: 1 (a new Ubuntu AMI replaced the Puppet master; `ami` is now in `ignore_changes`), 3 (`terraform apply` undid scale-out; the ASG now has `ignore_changes = [desired_capacity]`), 6 (IMDSv2 was not enforced; the master and the launch template now set `http_tokens = "required"`), 7 (disks were not explicitly encrypted; the master's root volume and the launch template now set `encrypted = true`), 18 (no Terraform version constraint; the root and every module now require `>= 1.7`).

## High: can break the platform

| # | Issue | Where | Fix |
|---|---|---|---|
| 2 | **Launch template changes do not roll out to running nodes.** The ASG uses `version = "$Latest"`. That string never changes, so the `instance_refresh` block is never triggered. Only instances launched later get the new template. | `module_aws_asg/main.tf` | Pass the launch template's `latest_version` into the ASG module and use it as `version`. Until then, start a refresh by hand (see [DEPLOYMENT.md](DEPLOYMENT.md)). |
| 4 | **Nodes serve the default nginx page until Puppet succeeds, and stay "healthy" if it never does.** nginx starts before the first Puppet run, so the health check passes on the default page. The first run ends with `|| true`, so a node that fails to enrol is never replaced. | `module_aws_launch_template/user_data_nodes.tftpl` | Start nginx only through Puppet, or make the health check request a file that exists only in the site repository. |

## Medium: security

| # | Issue | Where | Fix |
|---|---|---|---|
| 5 | **The autosign secret is stored in plain text** in the Terraform state, in the master's user data and in every node's user data. Any process on a node can read user data from the metadata service. | Both `.tftpl` files | Store the secret in SSM Parameter Store or Secrets Manager and read it at boot through an instance role. |
| 8 | **The SSH range is correct only in `ap-southeast-1`.** `3.0.5.32/29` is that region's EC2 Instance Connect range, but `region` is a variable. | `module_aws_security_groups/main.tf`, `module_aws_ec2_puppet_master/main.tf` | Look the range up with the `aws_ec2_managed_prefix_list` data source, or make it a variable. |
| 9 | **The state backend has no locking and no explicit encryption.** Two applies at once can corrupt the state. | `provider.tf` | Add `use_lockfile = true` and `encrypt = true`. |
| 10 | **The site is served over HTTP only.** | `module_aws_alb/main.tf` | Add an HTTPS listener with an ACM certificate and redirect port 80. |
| 11 | **The secret is inserted into shell and YAML without escaping.** A secret containing `"`, `$` or a backtick breaks the autosign script or `csr_attributes.yaml`. | Both `.tftpl` files | Use letters and digits only, or add a `validation` block to the variable. |

## Low: reliability and best practice

| # | Issue | Where | Fix |
|---|---|---|---|
| 12 | **Puppet packages come from the public Puppet repositories, unpinned (verify).** Perforce stopped publishing new Puppet releases there in 2025, so these packages may no longer get updates. The nodes also use the `el-9` repository on Amazon Linux 2023 instead of the `amazon-2023` one. | Both `.tftpl` files | Confirm the packages still install, pin versions, and consider OpenVox or the vendor's current repositories. |
| 13 | **No input validation.** Nothing checks `asg_min_size <= asg_desired_capacity <= asg_max_size` or that `cpu_threshold` is between 0 and 100. Three root variables have no description. | `variables.tf` | Add `validation` blocks and descriptions. |
| 14 | **The fleet never scales in**, and it uses the older simple scaling type. | `module_aws_asg/main.tf` | Replace the policy and alarm with one target tracking policy. |
| 15 | **The internal domain is hard-coded in two places** that must agree: the FQDN in the root `main.tf` and the zone name in the DNS module. | `main.tf`, `module_aws_dns/main.tf` | Make the zone name a DNS module input and build the FQDN from it. |
| 16 | **Puppet code changes never reach the master through Terraform**, because of `ignore_changes = [user_data]`. The Puppet code is also embedded in a shell script, so it cannot be linted. | `module_aws_ec2_puppet_master` | Keep the Puppet code in its own Git repository and deploy it to the master with r10k or a simple `git pull`. |
| 17 | **Single Puppet master with no backup of its CA.** | `module_aws_ec2_puppet_master` | Take scheduled EBS snapshots at minimum. |
| 19 | **Nodes run `dnf update -y` at boot.** Boot is slower and two nodes launched at different times can differ. | `user_data_nodes.tftpl` | Remove it, or bake an image. |
| 20 | **No ALB access logs and no common tags.** | `module_aws_alb/main.tf`, `provider.tf` | Enable access logs; add `default_tags` to the provider. |

## Test coverage gaps

- The unit tests check Terraform configuration and rendered text only. They do not run the bootstrap scripts or compile the Puppet code.
- The root wiring test cannot see inside modules, so it does not check that the same FQDN reaches the master, the DNS record and the nodes.
