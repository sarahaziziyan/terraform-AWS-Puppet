# terraform-AWS-Puppet

Terraform that builds a small, self-healing website platform on AWS. A **Puppet** server configures every web server and deploys the website from a Git repository.

- **Terraform** builds the infrastructure once: an HTTPS address (CloudFront), a load balancer, an auto scaling group of nginx web servers, a Puppet server and a private DNS name for it.
- **Puppet** keeps the web servers configured from then on. Push to your website's Git branch and every server picks it up within about 30 minutes, with no Terraform run.

Unhealthy servers are replaced automatically, and one server is added when average CPU stays above a threshold you set.

## What you need

- Terraform 1.7 or newer (tested with 1.16.4). This is enforced by `required_version = ">= 1.7"` in `provider.tf` and in each module, so an older version stops with an error. Check yours with `terraform version`
- AWS provider 6.x (`~> 6.0`), installed automatically by `terraform init`
- AWS credentials that can create EC2, load balancer, auto scaling, CloudFront, Route 53 and CloudWatch resources (`aws sts get-caller-identity` should work)
- An existing VPC with at least two subnets in different availability zones
- An existing EC2 key pair
- An existing S3 bucket for the Terraform state
- A public Git repository with an `index.html` at its root (your website)

## Run it

```bash
git clone git@github.com:sarahaziziyan/terraform-AWS-Puppet.git
cd terraform-AWS-Puppet
```

1. In `provider.tf`, set the `backend "s3"` bucket, key and region to your own bucket.
2. Create your variables file and fill it in. It is git-ignored; never commit it.

```bash
cp terraform_example_tfvars terraform.tfvars
```

3. Deploy.

```bash
terraform init
terraform plan
terraform apply
```

Wait 5 to 10 minutes after `apply` while the servers set themselves up.

## Variables

| Variable | Purpose |
|---|---|
| `region` | AWS region for all resources |
| `key_name` | Name of your EC2 key pair |
| `vpc_id` | VPC to deploy into |
| `subnet_ids` | Subnets for the load balancer and web servers (two or more zones) |
| `subnet_id` | Subnet for the Puppet server |
| `puppet_autosign_secret` | Shared secret that lets new web servers register with Puppet automatically. Keep it private |
| `site_repo_url` | Git repository that contains your website |
| `site_repo_branch` | Branch to deploy |
| `asg_min_size`, `asg_desired_capacity`, `asg_max_size` | Minimum, starting and maximum number of web servers. The starting number applies only when the group is first created |
| `cpu_threshold` | Average CPU % that adds one server |

## Use it

Open the site: print the address and browse to it. It is an `https://...cloudfront.net` address; plain HTTP is redirected to HTTPS. The load balancer's own address only accepts traffic from CloudFront.

```bash
terraform output -raw site_url
```

A new CloudFront distribution takes a few minutes to become reachable after the first `apply`.

- **Change the website:** push to the branch set in `site_repo_branch`.
- **Change the number of servers:** edit the `asg_*` values in `terraform.tfvars` and run `terraform apply`.
- **Remove everything:** run `terraform destroy`.

## Run the tests

The unit tests mock AWS, so they need no credentials and create nothing.

```bash
./run_tests.sh
```

## Limits

- The HTTPS address is a generated `*.cloudfront.net` name; there is no custom domain yet.
- The fleet scales out but never back in.
- One Puppet server. If it is down, running web servers keep serving, but new ones cannot finish setting up.
- The Terraform state has no locking.
- SSH access is set up for region `ap-southeast-1` only.

The full list, with fixes, is in [docs/KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md).

## More

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md): design and reasons
- [docs/INTERFACES.md](docs/INTERFACES.md): network endpoints, module inputs and outputs
- [docs/TESTING.md](docs/TESTING.md): unit tests and manual checks
- [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md): deployment steps
