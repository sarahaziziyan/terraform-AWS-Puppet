# Unit tests for module_aws_launch_template.
# Self-contained: the AWS provider is mocked, so no credentials or real resources are needed.
# Run from this module's folder:  terraform init && terraform test

mock_provider "aws" {
  mock_data "aws_ssm_parameter" {
    defaults = {
      value = "ami-0123456789abcdef0"
    }
  }
}

variables {
  key_name               = "test-key"
  security_group_ids     = ["sg-0123456789abcdef0"]
  site_repo_url          = "https://example.com/acme/site.git"
  site_repo_branch       = "release"
  puppet_master_fqdn     = "puppet.internal.puppet-server.com"
  puppet_autosign_secret = "unit-test-secret"
}

# Every web node is built from these settings.
run "template_uses_given_inputs" {
  command = apply

  assert {
    condition     = aws_launch_template.web.instance_type == "t3.micro"
    error_message = "Web nodes must be t3.micro."
  }

  assert {
    condition     = aws_launch_template.web.key_name == var.key_name
    error_message = "The template must use the key pair passed to the module."
  }

  assert {
    condition     = aws_launch_template.web.vpc_security_group_ids == toset(var.security_group_ids)
    error_message = "The template must use exactly the security groups passed to the module."
  }

  assert {
    condition     = nonsensitive(aws_launch_template.web.image_id) == "ami-0123456789abcdef0"
    error_message = "The template must boot from the AMI returned by the SSM parameter lookup."
  }
}

# The bootstrap script uses dnf and the el-9 Puppet repo, so the AMI must stay Amazon Linux 2023 x86_64.
run "ami_lookup_is_amazon_linux_2023" {
  command = apply

  assert {
    condition     = data.aws_ssm_parameter.al2023.name == "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
    error_message = "The AMI lookup must use the public Amazon Linux 2023 x86_64 SSM parameter."
  }
}

# The scale-out alarm evaluates 120 second periods, which needs detailed monitoring.
# New template versions must also become the default so the ASG picks them up.
run "monitoring_and_versioning" {
  command = apply

  assert {
    condition     = aws_launch_template.web.monitoring[0].enabled
    error_message = "Detailed monitoring must be enabled for the CPU alarm."
  }

  assert {
    condition     = aws_launch_template.web.update_default_version
    error_message = "update_default_version must be true."
  }
}

run "instances_are_tagged" {
  command = apply

  assert {
    condition = anytrue([
      for s in aws_launch_template.web.tag_specifications :
      s.resource_type == "instance" && s.tags["Name"] == "online-course" && s.tags["Created_By"] == "Terraform"
    ])
    error_message = "Instances must be tagged Name=online-course and Created_By=Terraform."
  }
}

# The node proves it may be auto-signed by sending the shared secret in its certificate request.
run "user_data_sends_autosign_secret" {
  command = apply

  assert {
    condition     = strcontains(base64decode(nonsensitive(aws_launch_template.web.user_data)), "1.2.840.113549.1.9.7: \"unit-test-secret\"")
    error_message = "csr_attributes.yaml must carry the shared secret as the challengePassword attribute."
  }

  assert {
    condition     = strcontains(base64decode(nonsensitive(aws_launch_template.web.user_data)), "chmod 600 /etc/puppetlabs/puppet/csr_attributes.yaml")
    error_message = "The file holding the secret must be readable by root only."
  }
}

# The node must point at the master by name and use a unique certname.
run "user_data_configures_puppet_agent" {
  command = apply

  assert {
    condition     = strcontains(base64decode(nonsensitive(aws_launch_template.web.user_data)), "puppet config set server puppet.internal.puppet-server.com --section main")
    error_message = "The agent must be pointed at the Puppet master FQDN passed to the module."
  }

  assert {
    condition     = strcontains(base64decode(nonsensitive(aws_launch_template.web.user_data)), "puppet config set certname \"$INSTANCE_ID\" --section main")
    error_message = "The agent's certname must be the EC2 instance ID (site.pp matches on it)."
  }

  assert {
    condition     = strcontains(base64decode(nonsensitive(aws_launch_template.web.user_data)), "X-aws-ec2-metadata-token")
    error_message = "The instance ID must be read with an IMDSv2 token; AL2023 rejects IMDSv1."
  }

  assert {
    condition     = strcontains(base64decode(nonsensitive(aws_launch_template.web.user_data)), "systemctl enable --now puppet")
    error_message = "The Puppet agent service must be enabled so nodes keep checking in."
  }
}

# The website repo and branch reach Puppet as facts. Names must match what site.pp reads.
run "user_data_publishes_site_facts" {
  command = apply

  assert {
    condition     = strcontains(base64decode(nonsensitive(aws_launch_template.web.user_data)), "site_repo_url=https://example.com/acme/site.git")
    error_message = "The site_repo_url fact must contain the repository URL passed to the module."
  }

  assert {
    condition     = strcontains(base64decode(nonsensitive(aws_launch_template.web.user_data)), "site_repo_branch=release")
    error_message = "The site_repo_branch fact must contain the branch passed to the module."
  }

  assert {
    condition     = strcontains(base64decode(nonsensitive(aws_launch_template.web.user_data)), "/etc/puppetlabs/facter/facts.d/site.txt")
    error_message = "The facts must be written to Facter's external facts folder."
  }
}

# Templating must leave a valid shell script behind.
run "user_data_is_a_clean_shell_script" {
  command = apply

  assert {
    condition     = startswith(base64decode(nonsensitive(aws_launch_template.web.user_data)), "#!/bin/bash")
    error_message = "User data must start with a shebang, otherwise cloud-init does not run it."
  }

  assert {
    condition     = strcontains(base64decode(nonsensitive(aws_launch_template.web.user_data)), "-w \"%%{http_code}\"")
    error_message = "The curl http_code format string must render with a single percent sign."
  }

  assert {
    condition     = !strcontains(base64decode(nonsensitive(aws_launch_template.web.user_data)), "$${")
    error_message = "No unrendered template placeholder may remain in the script."
  }
}

# Regression test for the README "Known issues" entry: $CLONE_DIR is used but never set,
# so `cp -a "$CLONE_DIR"/. ...` would copy the node's whole root filesystem into the web root.
run "user_data_does_not_use_undefined_clone_dir" {
  command = apply

  assert {
    condition = (
      !strcontains(base64decode(nonsensitive(aws_launch_template.web.user_data)), "$CLONE_DIR") ||
      strcontains(base64decode(nonsensitive(aws_launch_template.web.user_data)), "CLONE_DIR=")
    )
    error_message = "The script uses $CLONE_DIR without ever setting it. Remove that block or restore the git clone step."
  }
}

# Known issue 6: nodes must require IMDSv2 session tokens, so an SSRF bug
# cannot read the user data (and the autosign secret) with a plain GET.
run "imdsv2_is_required" {
  command = apply

  assert {
    condition = (
      aws_launch_template.web.metadata_options[0].http_endpoint == "enabled" &&
      aws_launch_template.web.metadata_options[0].http_tokens == "required" &&
      aws_launch_template.web.metadata_options[0].http_put_response_hop_limit == 1
    )
    error_message = "The launch template must require IMDSv2 (http_tokens = \"required\", hop limit 1)."
  }

  # The bootstrap script must keep using the token flow, or it breaks once IMDSv1 is off.
  assert {
    condition     = strcontains(base64decode(nonsensitive(aws_launch_template.web.user_data)), "X-aws-ec2-metadata-token:")
    error_message = "The bootstrap script must send an IMDSv2 token when reading instance metadata."
  }
}

# The ASG module needs this output.
run "output_exposes_template_id" {
  command = apply

  assert {
    condition     = output.id == aws_launch_template.web.id
    error_message = "id must be the launch template's ID."
  }
}
