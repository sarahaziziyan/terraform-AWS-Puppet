# Deployment

Deployment is manual, with Terraform, into a single environment. There is no CI/CD pipeline.

## First deployment

1. Set the S3 backend values in `provider.tf` and `bootstrap/versions.tf`. The bucket must already exist; enable versioning and encryption on it.
2. With administrator credentials, apply `bootstrap/` once: `cd bootstrap && terraform init && terraform apply`. It creates the autosign secret in SSM Parameter Store, the two instance roles that may read it, and the `iam:PassRole` policy on `terraform-user`.
3. Run `cp terraform_example_tfvars terraform.tfvars` and fill in the values.
4. With `terraform-user`, run `terraform init`, `terraform plan`, then `terraform apply`.
5. Wait 5 to 10 minutes, then open `terraform output -raw site_url` and run the integration checks in [TESTING.md](TESTING.md).

## Updating

Always read `terraform plan` before applying.

| What changed | How to deploy | Effect |
|---|---|---|
| Website content | Push to the branch in `site_repo_branch` | Nodes pick it up on their next Puppet run (up to 30 minutes). No Terraform run |
| Web node setup (user data, instance type) | `terraform apply` | Apply creates a new launch template version and updates the ASG to it, which starts a rolling instance refresh. Running nodes are replaced a batch at a time, keeping at least 50% healthy. `terraform plan` shows this as an in-place change to the ASG's `launch_template.version` |
| Nothing (a new Amazon Linux 2023 image was released) | `terraform apply` | The launch template always looks up the newest image, so apply creates a new version and starts a refresh, the same as above. If `plan` shows `image_id` changing on the launch template, this is why |
| ASG sizes or CPU threshold | Edit `terraform.tfvars`, then `terraform apply` | Minimum, maximum and threshold are applied in place. `asg_desired_capacity` is used only when the ASG is first created; later changes to it are ignored so that apply does not undo scale-out. To resize a running fleet, change `asg_min_size` (to add nodes) or `asg_max_size` (to remove nodes) and apply |
| Security groups, load balancer | `terraform apply` | Security groups are replaced create-before-destroy |
| CloudFront settings | `terraform apply` | Changes take a few minutes to reach all CloudFront locations. Cached pages expire within 5 minutes |
| Puppet code or master bootstrap script | Edit the files on the master directly | Terraform ignores changes to the master's user data, so `apply` does nothing |

### Replace every node without changing the template

A launch template change starts a refresh on its own. To replace every node without changing anything, for example after replacing the Puppet master, have Terraform recreate the launch template. The ASG then points at the new template, which starts the same rolling refresh:

```bash
terraform apply -replace=module.module_aws_launch_template.aws_launch_template.web
```

Follow its progress (read-only) with `aws autoscaling describe-instance-refreshes --auto-scaling-group-name "$(terraform output -raw asg_name)"`.

A new node passes the health check only after Puppet has deployed the site, and the refresh waits the 600 s grace period for each batch, so a refresh of a few nodes takes 20 to 30 minutes. If the site repository is broken (wrong URL or branch, no `index.html`), new nodes never become healthy and the refresh does not complete; the nodes it has not reached keep serving the last good copy. Fix the repository: the ASG keeps replacing the failed nodes, and once the repository is fixed the replacements succeed and the refresh finishes.

### Replacing the Puppet master

Avoid it. A new master has a new certificate authority, so every node must be replaced afterwards (see the section above). To do it on purpose:

```bash
terraform apply -replace=module.module_aws_ec2_puppet_master.aws_instance.puppet_master
```

Terraform ignores changes to the master's AMI and user data, so a newer Ubuntu image or an edited bootstrap script never replaces it. The master therefore keeps the image it was first built from: patch it in place with `apt`.

If a plan ever wants to replace `aws_instance.puppet_master` and you did not ask for it, do not apply. Find out which attribute forces the replacement first.

## Autosign secret

### Moving an existing stack to the SSM secret (once)

Stacks deployed before `bootstrap/` existed have the secret built into the master's boot script.

1. Apply `bootstrap/` with administrator credentials (first deployment, step 2).
2. Delete the `puppet_autosign_secret` line from `terraform.tfvars`.
3. Replace the master. Terraform ignores changes to its boot script, so a plain apply would leave it on the old secret and new nodes could not enrol:

```bash
terraform apply -replace=module.module_aws_ec2_puppet_master.aws_instance.puppet_master
```

The same apply creates a new launch template version, so the nodes are replaced by a rolling refresh. Running nodes keep serving the site until their replacements are healthy.

### Rotating the secret

Increase `autosign_secret_version` in `bootstrap/` by one and apply it with administrator credentials. Terraform writes a new random secret; nothing is stored in its state.

The master reads the secret from SSM for every request, so the new one applies immediately. Nodes that are already enrolled keep working. New nodes read the new secret at boot.

## CloudFront origin header secret

CloudFront adds a secret `X-Origin-Verify` header to every request it sends to the ALB, and the ALB answers 403 to requests without it. Terraform generates the value (`random_password.origin_header` in `main.tf`); no variable is needed.

To rotate it:

```bash
terraform apply -replace=random_password.origin_header
```

The ALB rule changes within seconds, but CloudFront takes a few minutes to send the new value from every location. Until it does, some requests that miss the cache get 403. Rotate at a quiet time. The first apply that adds the header to an existing stack has the same short window.

## State locking and encryption

Both backends (`provider.tf` and `bootstrap/versions.tf`) set `encrypt = true` and `use_lockfile = true`. During `plan` and `apply`, Terraform creates `<state key>.tflock` next to the state in the bucket and deletes it at the end. A second run started meanwhile stops with "Error acquiring the state lock" instead of overwriting the state.

- After changing backend settings, run `terraform init -reconfigure` once in that folder. The bucket and key are unchanged, so no state is moved.
- The identity that runs Terraform needs `s3:GetObject`, `s3:PutObject` and `s3:DeleteObject` on the `.tflock` object as well as on the state: `build/online-course/terraform.tfstate.tflock` for `terraform-user`, `bootstrap/online-course/terraform.tfstate.tflock` for the admin.
- If a run is killed and leaves the lock behind, release it with `terraform force-unlock <LOCK_ID>` (the ID is in the error message). Only do this when no other run is active.

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
4. Use short-lived credentials (OIDC) instead of stored access keys.
