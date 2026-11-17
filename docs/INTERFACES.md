# Interfaces reference

The project's interfaces are its network endpoints, the Terraform inputs and outputs of the root and of each module, and the Puppet facts shared between the nodes and the master.

## Network endpoints

| Endpoint | Protocol / port | Who may connect | Purpose |
|---|---|---|---|
| CloudFront address (`site_url` output) | HTTPS 443 (HTTP 80 redirects) | Anyone | Serves the website |
| ALB DNS name (`alb_dns_name` output) | HTTP 80 | CloudFront only (managed prefix list `com.amazonaws.global.cloudfront.origin-facing`) | CloudFront's origin. Target health check: `GET /` must return `200` |
| Puppet master `puppet.internal.puppet-server.com` | TCP 8140 | Web node security group only | Puppet agent catalog requests and certificate signing |
| SSH to web nodes and master | TCP 22 | EC2 Instance Connect only (managed prefix list `com.amazonaws.<region>.ec2-instance-connect`) | Operator access |

## Root module inputs

See the table in the [README](../README.md#variables). All are required; none have defaults.

## Root module outputs

| Output | Description |
|---|---|
| `site_url` | HTTPS address of the website (CloudFront) |
| `cloudfront_distribution_id` | ID of the CloudFront distribution, for cache invalidations |
| `puppet_master_private_ip` | Private IP of the Puppet master |
| `alb_dns_name` | DNS name of the load balancer. Reachable only from CloudFront |
| `alb_zone_id` | Hosted zone ID of the ALB (for alias records) |
| `target_group_arn` | Target group ARN |
| `asg_name` | Auto Scaling Group name |
| `asg_min_size`, `asg_desired_capacity`, `asg_max_size` | ASG minimum and maximum as last applied by Terraform; desired capacity as last read from AWS (the scaling policy changes it) |

## Module interfaces

| Module | Inputs | Outputs |
|---|---|---|
| `module_aws_security_groups` | `vpc_id` | `alb_security_group_id`, `web_security_group_id` |
| `module_aws_ec2_puppet_master` | `vpc_id`, `subnet_id`, `key_name`, `web_security_group_id`, `puppet_master_fqdn`, `autosign_secret_parameter_name`, `instance_profile_name` | `private_ip`, `instance_profile_name` |
| `module_aws_dns` | `vpc_id`, `puppet_master_fqdn`, `puppet_master_private_ip` | `zone_id` |
| `module_aws_launch_template` | `key_name`, `security_group_ids`, `site_repo_url`, `site_repo_branch`, `puppet_master_fqdn`, `autosign_secret_parameter_name`, `instance_profile_name` | `id`, `latest_version`, `instance_profile_name` |
| `module_aws_alb` | `vpc_id`, `subnet_ids`, `security_group_ids` | `dns_name`, `zone_id`, `target_group_arn` |
| `module_aws_cloudfront` | `alb_dns_name` | `domain_name`, `url`, `distribution_id`, `origin_domain_name` |
| `module_aws_asg` | `subnet_ids`, `launch_template_id`, `launch_template_version`, `target_group_arns`, `min_size`, `desired_capacity`, `max_size`, `cpu_threshold` | `name`, `min_size`, `desired_capacity`, `max_size`, `launch_template_version` |

All module inputs are required. Every module requires the AWS provider `~> 6.0` (`versions.tf`).

## Bootstrap interface

`bootstrap/` is applied separately, with administrator credentials. The main stack refers to what it creates by name only.

| `bootstrap/` output | Main stack variable | Default |
|---|---|---|
| `autosign_secret_parameter_name` | `autosign_secret_parameter_name` | `/puppet/autosign-secret` |
| `puppet_master_instance_profile_name` | `puppet_master_instance_profile_name` | `puppet-master-autosign-reader` |
| `web_node_instance_profile_name` | `web_node_instance_profile_name` | `web-node-autosign-reader` |

`bootstrap/` also gives `terraform-user` `iam:PassRole` on the two roles, limited to EC2.

## Puppet interface

The launch template module (nodes) and the Puppet master module must agree on these. Each module's tests check its own side.

| Item | Node side | Master side |
|---|---|---|
| Facts `site_repo_url`, `site_repo_branch` | Written to `/etc/puppetlabs/facter/facts.d/site.txt` | Read by `site.pp` and passed to `profile::website` |
| Autosign secret | Read at boot from the SSM parameter `autosign_secret_parameter_name`, sent in the certificate request as `challengePassword` (OID `1.2.840.113549.1.9.7`), then deleted | Read from the same parameter by `/etc/puppetlabs/puppet/autosign.sh` for each request and compared |
| Certname | The EC2 instance ID | `site.pp` matches `/^i-[0-9a-f]+$/` |

Class: `profile::website(repo_url, branch = 'main', src_dir = '/opt/website-src')`.
