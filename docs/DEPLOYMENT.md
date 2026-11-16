# Deployment

Deployment is manual, with Terraform, into a single environment. There is no CI/CD pipeline.

## First deployment

1. Set the S3 backend values in `provider.tf`. The bucket must already exist; enable versioning and encryption on it.
2. Run `cp terraform_example_tfvars terraform.tfvars` and fill in the values.
3. Run `terraform init`, `terraform plan`, then `terraform apply`.
4. Wait 5 to 10 minutes, then run the integration checks in [TESTING.md](TESTING.md).

## Updating

Always read `terraform plan` before applying.

| What changed | How to deploy | Effect |
|---|---|---|
| Website content | Push to the branch in `site_repo_branch` | Nodes pick it up on their next Puppet run (up to 30 minutes). No Terraform run |
| Web node setup (user data, instance type) | `terraform apply` | Apply creates a new launch template version and updates the ASG to it, which starts a rolling instance refresh. Running nodes are replaced a batch at a time, keeping at least 50% healthy. `terraform plan` shows this as an in-place change to the ASG's `launch_template.version` |
| Nothing (a new Amazon Linux 2023 image was released) | `terraform apply` | The launch template always looks up the newest image, so apply creates a new version and starts a refresh, the same as above. If `plan` shows `image_id` changing on the launch template, this is why |
| ASG sizes or CPU threshold | Edit `terraform.tfvars`, then `terraform apply` | Minimum, maximum and threshold are applied in place. `asg_desired_capacity` is used only when the ASG is first created; later changes to it are ignored so that apply does not undo scale-out. To resize a running fleet, change `asg_min_size`/`asg_max_size` or run `aws autoscaling set-desired-capacity` |
| Security groups, load balancer | `terraform apply` | Security groups are replaced create-before-destroy |
| Puppet code or master bootstrap script | Edit the files on the master directly | Terraform ignores changes to the master's user data, so `apply` does nothing |

### Start an instance refresh by hand

A launch template change starts a refresh on its own. Start one by hand only when you want to replace every node without changing the template, for example after replacing the Puppet master:

```bash
aws autoscaling start-instance-refresh --auto-scaling-group-name "$(terraform output -raw asg_name)" \
  --preferences '{"MinHealthyPercentage": 50}'
```

Follow its progress with `aws autoscaling describe-instance-refreshes --auto-scaling-group-name "$(terraform output -raw asg_name)"`.

A new node counts as healthy as soon as the load balancer health check passes, which can happen before Puppet has configured it (see [KNOWN_ISSUES.md](KNOWN_ISSUES.md), issue 4). Check the site after a refresh finishes.

### Replacing the Puppet master

Avoid it. A new master has a new certificate authority, so every node must be replaced afterwards (start an instance refresh). To do it on purpose:

```bash
terraform apply -replace=module.module_aws_ec2_puppet_master.aws_instance.puppet_master
```

Terraform ignores changes to the master's AMI and user data, so a newer Ubuntu image or an edited bootstrap script never replaces it. The master therefore keeps the image it was first built from: patch it in place with `apt`.

If a plan ever wants to replace `aws_instance.puppet_master` and you did not ask for it, do not apply. Find out which attribute forces the replacement first.

## Rollback

- **Infrastructure:** revert the commit and apply again. A reverted launch template change creates a new template version and starts a refresh by itself.
- **Website content:** revert in the site repository.
- **State problems:** restore an earlier version of the state object in S3. This needs bucket versioning.

## More than one environment

Not supported yet. To add environments, use one state key and one `.tfvars` file per environment. The `internal.puppet-server.com` domain, the `puppet-master` security group name and the `Name` tags are hard-coded and would need to vary per environment.

## Suggested CI/CD (not implemented)

1. On pull request: `terraform fmt -check -recursive`, `./run_tests.sh`, a linter (`tflint`, `checkov` or `trivy config .`), then `terraform plan` posted to the pull request.
2. On merge to `main`: apply to staging.
3. To production: manual approval, then apply the same commit.
4. Use short-lived credentials (OIDC) instead of stored access keys, and turn on state locking (`use_lockfile = true`, Terraform 1.10 or newer).
