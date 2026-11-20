# Known issues

Open problems found by reviewing the code. Items marked **(verify)** are likely but were not confirmed on a real deployment. Issue numbers are stable: a fixed issue is removed and its number is not reused.

Fixed so far: 21 (any CloudFront distribution, including other AWS customers', could reach the ALB; CloudFront now sends a secret `X-Origin-Verify` header and the ALB answers 403 to requests without it. The plain-HTTP hop from CloudFront to the ALB remains and is now part of issue 22), 9 (the state backend had no locking and no explicit encryption; both backends now set `use_lockfile = true` and `encrypt = true`), 8 (the SSH range `3.0.5.32/29` was hard-coded and correct only in `ap-southeast-1`; both SSH rules now use the region's AWS-managed `ec2-instance-connect` prefix list), 5 (the autosign secret was stored in plain text in the state, tfvars and user data; it now lives only in an encrypted SSM parameter created by the admin-applied `bootstrap/` config, which the instances read through their own roles), 11 (the secret was inserted into shell and YAML without escaping; it is now generated with letters and digits only), 10 (the site was served over HTTP only; visitors now use HTTPS through CloudFront, HTTP is redirected, and the ALB accepts traffic only from CloudFront), 4 (nodes served the default nginx page until Puppet succeeded and stayed healthy if it never did; nginx is now started only by Puppet after the site files are in place, the first Puppet run is retried instead of ignored, and the grace period is 600 s), 2 (launch template changes did not roll out to running nodes; the ASG now uses the template's `latest_version`, so a change starts an instance refresh), 1 (a new Ubuntu AMI replaced the Puppet master; `ami` is now in `ignore_changes`), 3 (`terraform apply` undid scale-out; the ASG now has `ignore_changes = [desired_capacity]`), 6 (IMDSv2 was not enforced; the master and the launch template now set `http_tokens = "required"`), 7 (disks were not explicitly encrypted; the master's root volume and the launch template now set `encrypted = true`), 18 (no Terraform version constraint; the root and every module now require `>= 1.7`).

## High: can break the platform

| # | Issue | Where | Fix |
|---|---|---|---|

## Medium: security

| # | Issue | Where | Fix |
|---|---|---|---|

## Low: reliability and best practice

| # | Issue | Where | Fix |
|---|---|---|---|
| 12 | **Puppet packages come from the public Puppet repositories, unpinned (verify).** Perforce stopped publishing new Puppet releases there in 2025, so these packages may no longer get updates. The nodes also use the `el-9` repository on Amazon Linux 2023 instead of the `amazon-2023` one. | `user_data_nodes.tftpl`; `puppet_master.tftpl` in terraform-aws-puppet-server | Confirm the packages still install, pin versions, and consider OpenVox or the vendor's current repositories. |
| 13 | **No input validation.** Nothing checks `asg_min_size <= asg_desired_capacity <= asg_max_size` or that `cpu_threshold` is between 0 and 100. Three root variables have no description. | `variables.tf` | Add `validation` blocks and descriptions. |
| 14 | **The fleet never scales in**, and it uses the older simple scaling type. | `module_aws_asg/main.tf` | Replace the policy and alarm with one target tracking policy. |
| 15 | **The internal domain is hard-coded in two places** that must agree: the FQDN in the root `main.tf` and the zone name in the DNS module. | `main.tf`, `module_aws_dns/main.tf` | Make the zone name a DNS module input and build the FQDN from it. |
| 22 | **The site address is a generated `*.cloudfront.net` name, and the hop from CloudFront to the ALB is plain HTTP.** The ALB has no certificate, because there is no domain to issue one for. Between CloudFront and the ALB, the pages and the secret origin header travel unencrypted. | `module_aws_cloudfront`, `module_aws_alb` | Add a custom domain: an ACM certificate in `us-east-1` for CloudFront, an alias on the distribution, and a DNS record. Then add an ACM certificate in the stack's region, an HTTPS listener on the ALB, and set the origin to `https-only`. |
| 16 | **Puppet code changes never reach the master through Terraform**, because of `ignore_changes = [user_data]`. The Puppet code is also embedded in a shell script, so it cannot be linted. | terraform-aws-puppet-server repository | Keep the Puppet code in its own Git repository and deploy it to the master with r10k or a simple `git pull`. |
| 17 | **Single Puppet master with no backup of its CA.** | terraform-aws-puppet-server repository | Take scheduled EBS snapshots at minimum. |
| 19 | **Nodes run `dnf update -y` at boot.** Boot is slower and two nodes launched at different times can differ. | `user_data_nodes.tftpl` | Remove it, or bake an image. |
| 20 | **No ALB access logs and no common tags.** | `module_aws_alb/main.tf`, `provider.tf` | Enable access logs; add `default_tags` to the provider. |

## Test coverage gaps

- The unit tests check Terraform configuration and rendered text only. They do not run the bootstrap scripts or compile the Puppet code.
- The root wiring test cannot see inside modules, so it does not check that the same FQDN reaches the master, the DNS record and the nodes.
