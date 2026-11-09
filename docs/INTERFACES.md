# Interfaces reference

The project's interfaces are its network endpoints, the Terraform inputs and outputs of the root and of each module, and the Puppet facts shared between the nodes and the master.

## Network endpoints

| Endpoint | Protocol / port | Who may connect | Purpose |
|---|---|---|---|
| ALB DNS name (`alb_dns_name` output) | HTTP 80 | Anyone (`0.0.0.0/0`) | Serves the website. Health check: `GET /` must return `200` |
| Puppet master `puppet.internal.puppet-server.com` | TCP 8140 | Web node security group only | Puppet agent catalog requests and certificate signing |
| SSH to web nodes and master | TCP 22 | `3.0.5.32/29`, the EC2 Instance Connect range of `ap-southeast-1` only | Operator access |

## Root module inputs

See the table in the [README](../README.md#variables). All are required; none have defaults.

## Root module outputs

| Output | Description |
|---|---|
| `puppet_master_private_ip` | Private IP of the Puppet master |
| `alb_dns_name` | DNS name of the load balancer |
| `alb_zone_id` | Hosted zone ID of the ALB (for alias records) |
| `target_group_arn` | Target group ARN |
| `asg_name` | Auto Scaling Group name |
| `asg_min_size`, `asg_desired_capacity`, `asg_max_size` | ASG sizes as last applied by Terraform |

## Module interfaces

| Module | Inputs | Outputs |
|---|---|---|
| `module_aws_security_groups` | `vpc_id` | `alb_security_group_id`, `web_security_group_id` |
| `module_aws_ec2_puppet_master` | `vpc_id`, `subnet_id`, `key_name`, `web_security_group_id`, `puppet_master_fqdn`, `puppet_autosign_secret` | `private_ip` |
| `module_aws_dns` | `vpc_id`, `puppet_master_fqdn`, `puppet_master_private_ip` | `zone_id` |
| `module_aws_launch_template` | `key_name`, `security_group_ids`, `site_repo_url`, `site_repo_branch`, `puppet_master_fqdn`, `puppet_autosign_secret` | `id` |
| `module_aws_alb` | `vpc_id`, `subnet_ids`, `security_group_ids` | `dns_name`, `zone_id`, `target_group_arn` |
| `module_aws_asg` | `subnet_ids`, `launch_template_id`, `target_group_arns`, `min_size`, `desired_capacity`, `max_size`, `cpu_threshold` | `name`, `min_size`, `desired_capacity`, `max_size` |

All module inputs are required. Every module requires the AWS provider `~> 6.0` (`versions.tf`).

## Puppet interface

The launch template module (nodes) and the Puppet master module must agree on these. Each module's tests check its own side.

| Item | Node side | Master side |
|---|---|---|
| Facts `site_repo_url`, `site_repo_branch` | Written to `/etc/puppetlabs/facter/facts.d/site.txt` | Read by `site.pp` and passed to `profile::website` |
| Autosign secret | Sent in the certificate request as `challengePassword` (OID `1.2.840.113549.1.9.7`) | Compared by `/etc/puppetlabs/puppet/autosign.sh` |
| Certname | The EC2 instance ID | `site.pp` matches `/^i-[0-9a-f]+$/` |

Class: `profile::website(repo_url, branch = 'main', src_dir = '/opt/website-src')`.
