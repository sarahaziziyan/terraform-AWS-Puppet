# Testing guide

| Level | Needs AWS | Section |
|---|---|---|
| Unit tests | No | 1 |
| Static checks | No | 2 |
| Plan review | Yes (read-only) | 3 |
| Puppet code checks | No | 4 |
| Integration test | Yes (creates resources) | 5 |

## 1. Unit tests

Written with Terraform's built-in test framework (`terraform test`, Terraform 1.7 or newer). The AWS provider is mocked, so the tests need no credentials and create nothing.

Run every suite (each module, `bootstrap/`, then the root):

```bash
./run_tests.sh
```

Run one module on its own:

```bash
cd modules/aws/module_aws_asg
terraform init
terraform test
```

| Location | Scope |
|---|---|
| `modules/aws/<module>/tests/*.tftest.hcl` | One module in isolation: its variables, resources, outputs and rendered bootstrap script |
| `bootstrap/tests/bootstrap.tftest.hcl` | The admin-applied config: encrypted write-only secret, read-only instance roles, PassRole limited to those roles |
| `tests/root_wiring.tftest.hcl` | How the root connects the modules and passes inputs through |

Each module is self-contained so it can move to its own repository. It has its own `versions.tf` and its own `tests/` folder with its own mocks and inputs, and refers to nothing outside its folder. The root wiring test stays in this repository.

The Puppet server module's tests live in its own repository, [terraform-aws-puppet-server](https://github.com/sarahaziziyan/terraform-aws-puppet-server), and run there in GitHub Actions on every pull request. Here, the root wiring test checks only that the pinned version still accepts the root's inputs and provides the outputs it uses. `terraform init` downloads the module from GitHub, so the root suite needs internet access.

The unit tests do not prove that AWS accepts the configuration, that the bootstrap scripts run, or that the Puppet code compiles. Sections 4 and 5 cover those.

## 2. Static checks

```bash
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

Optional linters: `tflint`, `checkov` or `trivy config .`.

## 3. Plan review

```bash
terraform plan -out=tfplan
```

`tfplan` files are git-ignored. Check that the plan touches only what you expect. In particular, the plan must not replace `aws_instance.puppet_master` unless you intend it (see [DEPLOYMENT.md](DEPLOYMENT.md)).

## 4. Puppet code checks

The Puppet code is embedded in `puppet_master.tftpl` in the [terraform-aws-puppet-server](https://github.com/sarahaziziyan/terraform-aws-puppet-server) repository, so it cannot be linted in place. Copy the `profile::website` class and the `site.pp` content into `.pp` files, replace each `$${` with `${`, then run:

```bash
puppet parser validate website.pp site.pp
puppet-lint website.pp site.pp
```

## 5. Integration test

Deploy to a scratch environment: a separate state key and `terraform.tfvars`, with small ASG sizes. Destroy it afterwards.

| Check | Command | Expected |
|---|---|---|
| Site is served over HTTPS | `curl -i $(terraform output -raw site_url)/` | `200` and your `index.html`, not the default nginx page |
| HTTP is redirected | `curl -i http://$(terraform output -raw site_url \| sed 's#https://##')/` | `301` to the `https://` address |
| ALB is not public | `curl -m 10 http://$(terraform output -raw alb_dns_name)/` | Times out: only CloudFront may connect |
| ALB needs the origin header | From a web node (inside the VPC, but not CloudFront): `curl -i http://<alb_dns_name>/` | `403 Forbidden`: requests without the secret header are not forwarded |
| Targets healthy | `aws elbv2 describe-target-health --target-group-arn $(terraform output -raw target_group_arn)` | All `healthy` |
| Nodes enrolled | On the master: `sudo /opt/puppetlabs/bin/puppetserver ca list --all` | One signed certificate per instance ID |
| Agent run works | On a node: `sudo /opt/puppetlabs/bin/puppet agent --test` | Exit code 0 or 2, no errors |
| Content updates | Push a change to the site repo, then run `puppet agent --test` on a node | New content served |
| Self-healing | Terminate one instance | The ASG launches a replacement that becomes healthy within about 10 minutes |
| Secret not on nodes | On a node: `sudo ls /etc/puppetlabs/puppet/csr_attributes.yaml` | `No such file or directory` (deleted after the first Puppet run) |
| Node setup | On a node: `tail -n 20 /var/log/user_data.log` | Ends with `Puppet agent configured as i-...`, not `ERROR: Puppet did not configure this node` |
| Scale-out | Generate CPU load above `cpu_target` on the nodes (for example with `stress-ng`) | The `TargetTracking-*-AlarmHigh-*` alarm fires and nodes are added |
| Working hours | `aws autoscaling describe-scheduled-actions --auto-scaling-group-name $(terraform output -raw asg_name)` | `working-hours-start` and `working-hours-stop` with the expected recurrence and time zone; after the stop time, no instances and `curl` on `site_url` gives `503` |
| Scale-in | Stop the load and wait (scale-in is gradual, about 15 minutes or more) | The `TargetTracking-*-AlarmLow-*` alarm fires and nodes are removed, never below `asg_min_size` |

Bootstrap logs: `/var/log/user_data.log` on web nodes, `/var/log/cloud-init-output.log` on the master.

Clean up:

```bash
terraform destroy
```
