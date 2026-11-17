# Unit tests for module_aws_ec2_puppet_master.
# Self-contained: the AWS provider is mocked, so no credentials or real resources are needed.
# Run from this module's folder:  terraform init && terraform test

mock_provider "aws" {
  mock_data "aws_region" {
    defaults = {
      region = "ap-southeast-1"
    }
  }

  mock_data "aws_ec2_managed_prefix_list" {
    defaults = {
      id = "pl-0instanceconnect01"
    }
  }

  mock_data "aws_ami" {
    defaults = {
      id = "ami-0123456789abcdef0"
    }
  }
}

variables {
  vpc_id                = "vpc-0123456789abcdef0"
  subnet_id             = "subnet-0aaaaaaaaaaaaaaa1"
  key_name              = "test-key"
  web_security_group_id = "sg-0123456789abcdef0"
  puppet_master_fqdn    = "puppet.internal.puppet-server.com"

  autosign_secret_parameter_name = "/test/autosign-secret"
  instance_profile_name          = "test-master-profile"
}

# The master holds the CA, so only web nodes may reach the Puppet port.
run "puppet_port_open_only_to_web_nodes" {
  command = apply

  assert {
    condition     = aws_vpc_security_group_ingress_rule.puppet_master_puppet.security_group_id == aws_security_group.puppet_master.id
    error_message = "The Puppet rule must be attached to the master's security group."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.puppet_master_puppet.referenced_security_group_id == var.web_security_group_id
    error_message = "Port 8140 must be open to the web nodes' security group."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.puppet_master_puppet.cidr_ipv4 == null
    error_message = "The Puppet rule must not use a CIDR; it must reference the web security group."
  }

  assert {
    condition = (
      aws_vpc_security_group_ingress_rule.puppet_master_puppet.ip_protocol == "tcp" &&
      aws_vpc_security_group_ingress_rule.puppet_master_puppet.from_port == 8140 &&
      aws_vpc_security_group_ingress_rule.puppet_master_puppet.to_port == 8140
    )
    error_message = "The Puppet rule must be TCP port 8140 only."
  }
}

# SSH is limited to the EC2 Instance Connect range, never the whole internet.
run "ssh_limited_to_instance_connect" {
  command = apply

  # Known issue 8: the range comes from the region's managed list, not a hard-coded CIDR.
  assert {
    condition = (
      aws_vpc_security_group_ingress_rule.puppet_master_instance_connect.prefix_list_id == data.aws_ec2_managed_prefix_list.instance_connect.id &&
      aws_vpc_security_group_ingress_rule.puppet_master_instance_connect.cidr_ipv4 == null
    )
    error_message = "SSH must be limited to the region's EC2 Instance Connect prefix list, not a fixed address range."
  }

  assert {
    condition     = data.aws_ec2_managed_prefix_list.instance_connect.name == "com.amazonaws.ap-southeast-1.ec2-instance-connect"
    error_message = "The prefix list must be the one for the current region."
  }

  assert {
    condition = (
      aws_vpc_security_group_ingress_rule.puppet_master_instance_connect.from_port == 22 &&
      aws_vpc_security_group_ingress_rule.puppet_master_instance_connect.to_port == 22
    )
    error_message = "The SSH rule must be port 22 only."
  }
}

# Puppet Server needs enough memory and disk, and must sit where the caller says.
run "instance_is_sized_and_placed_correctly" {
  command = apply

  assert {
    condition     = aws_instance.puppet_master.instance_type == "t3.medium"
    error_message = "The Puppet master must be a t3.medium (Puppet Server needs about 4 GB of memory)."
  }

  assert {
    condition     = aws_instance.puppet_master.root_block_device[0].volume_size == 30
    error_message = "The root volume must be 30 GB."
  }

  # Known issue 7: the disk holds the Puppet CA's private key.
  assert {
    condition     = aws_instance.puppet_master.root_block_device[0].encrypted == true
    error_message = "The root volume must be encrypted explicitly, not left to the account's EBS default."
  }

  assert {
    condition     = aws_instance.puppet_master.subnet_id == var.subnet_id && aws_instance.puppet_master.key_name == var.key_name
    error_message = "The instance must use the subnet and key pair passed to the module."
  }

  assert {
    condition     = aws_instance.puppet_master.vpc_security_group_ids == toset([aws_security_group.puppet_master.id])
    error_message = "The instance must use only the master's own security group."
  }

  assert {
    condition     = aws_instance.puppet_master.ami == data.aws_ami.ubuntu.id
    error_message = "The instance must boot from the looked-up Ubuntu AMI."
  }
}

# Known issue 6: the metadata service must require IMDSv2 session tokens,
# so an SSRF bug cannot read the user data (and the autosign secret) with a plain GET.
run "imdsv2_is_required" {
  command = apply

  assert {
    condition = (
      aws_instance.puppet_master.metadata_options[0].http_endpoint == "enabled" &&
      aws_instance.puppet_master.metadata_options[0].http_tokens == "required"
    )
    error_message = "The Puppet master must require IMDSv2 (http_tokens = \"required\")."
  }

  assert {
    condition     = aws_instance.puppet_master.metadata_options[0].http_put_response_hop_limit == 1
    error_message = "The IMDS hop limit must be 1 so tokens cannot be fetched from beyond the instance."
  }
}

# The AMI lookup must stay pinned to Canonical's Ubuntu 22.04, which the bootstrap script assumes.
run "ami_lookup_is_canonical_ubuntu_jammy" {
  command = apply

  assert {
    condition     = data.aws_ami.ubuntu.owners == tolist(["099720109477"])
    error_message = "The AMI must be owned by Canonical (099720109477)."
  }

  assert {
    condition     = anytrue([for f in data.aws_ami.ubuntu.filter : f.name == "name" && anytrue([for v in f.values : strcontains(v, "ubuntu-jammy-22.04-amd64")])])
    error_message = "The AMI filter must select Ubuntu 22.04 (jammy) amd64, matching the puppet8-release-jammy package."
  }
}

# The server's names are fixed at first start (the CA is created then), so they must come from the input.
run "bootstrap_sets_puppet_names_from_fqdn" {
  command = apply

  assert {
    condition     = strcontains(nonsensitive(aws_instance.puppet_master.user_data), "puppet config set certname puppet.internal.puppet-server.com --section main")
    error_message = "The bootstrap script must set certname to the Puppet master FQDN."
  }

  assert {
    condition     = strcontains(nonsensitive(aws_instance.puppet_master.user_data), "puppet config set server puppet.internal.puppet-server.com --section main")
    error_message = "The bootstrap script must set server to the Puppet master FQDN."
  }

  assert {
    condition     = strcontains(nonsensitive(aws_instance.puppet_master.user_data), "dns_alt_names puppet,puppet.internal.puppet-server.com")
    error_message = "The bootstrap script must include the FQDN in dns_alt_names."
  }
}

# Autosign is what lets disposable ASG nodes enrol; it must compare against the shared secret.
# Known issue 5: the secret is read from SSM at boot through the instance role, never embedded.
run "bootstrap_installs_autosign_with_secret" {
  command = apply

  assert {
    condition     = aws_instance.puppet_master.iam_instance_profile == "test-master-profile"
    error_message = "The master must use the instance profile passed to the module (it may read the secret)."
  }

  assert {
    condition     = strcontains(nonsensitive(aws_instance.puppet_master.user_data), "EXPECTED=$(/usr/bin/aws ssm get-parameter --region ap-southeast-1 --name \"/test/autosign-secret\"")
    error_message = "autosign.sh must read the secret from the SSM parameter passed to the module, for every request."
  }

  assert {
    condition     = strcontains(nonsensitive(aws_instance.puppet_master.user_data), "[ -n \"$EXPECTED\" ] && [ \"$GOT\" = \"$EXPECTED\" ]")
    error_message = "autosign.sh must reject every request when the secret cannot be read."
  }

  # The boot check must not print or store the secret: it asks only for the parameter version.
  assert {
    condition     = strcontains(nonsensitive(aws_instance.puppet_master.user_data), "--with-decryption --query Parameter.Version --output text > /dev/null")
    error_message = "The boot-time check must only confirm the secret is readable, without logging or storing it."
  }

  assert {
    condition     = strcontains(nonsensitive(aws_instance.puppet_master.user_data), "puppet config set autosign /etc/puppetlabs/puppet/autosign.sh --section server")
    error_message = "The bootstrap script must register the autosign script with Puppet Server."
  }

  assert {
    condition     = strcontains(nonsensitive(aws_instance.puppet_master.user_data), "chmod 750 /etc/puppetlabs/puppet/autosign.sh")
    error_message = "The autosign script must be executable, otherwise Puppet Server ignores it."
  }
}

# Terraform and Puppet both use ${...}. Puppet variables must survive templating untouched.
run "bootstrap_keeps_puppet_variables_intact" {
  command = apply

  assert {
    condition     = strcontains(nonsensitive(aws_instance.puppet_master.user_data), "/usr/bin/test -f $${src_dir}/index.html")
    error_message = "The Puppet variable $${src_dir} must be preserved in the rendered manifest."
  }

  assert {
    condition     = strcontains(nonsensitive(aws_instance.puppet_master.user_data), "source  => \"file://$${src_dir}\"")
    error_message = "The Puppet variable $${src_dir} must be preserved in the file resource source."
  }

  assert {
    condition     = !strcontains(nonsensitive(aws_instance.puppet_master.user_data), "$$")
    error_message = "No Terraform escape sequence ($$) may remain in the rendered script."
  }
}

# The Puppet code written by the script is what configures every web node.
run "bootstrap_writes_puppet_code_for_web_nodes" {
  command = apply

  assert {
    condition     = strcontains(nonsensitive(aws_instance.puppet_master.user_data), "puppet module install puppetlabs-vcsrepo")
    error_message = "The vcsrepo module must be installed; profile::website depends on it."
  }

  assert {
    condition     = strcontains(nonsensitive(aws_instance.puppet_master.user_data), "class profile::website (")
    error_message = "The bootstrap script must write the profile::website class."
  }

  assert {
    condition     = strcontains(nonsensitive(aws_instance.puppet_master.user_data), "node /^i-[0-9a-f]+$/ {")
    error_message = "site.pp must match nodes whose certname is an EC2 instance ID."
  }

  assert {
    condition = (
      strcontains(nonsensitive(aws_instance.puppet_master.user_data), "repo_url => $facts['site_repo_url']") &&
      strcontains(nonsensitive(aws_instance.puppet_master.user_data), "branch   => $facts['site_repo_branch']")
    )
    error_message = "site.pp must read the repo URL and branch from the facts the web nodes publish."
  }

  # Known issue 4: nginx must start only after the site files are in place, so a node whose
  # site deployment failed fails the health check instead of serving the default page.
  assert {
    condition     = strcontains(nonsensitive(aws_instance.puppet_master.user_data), "require => [Package['nginx'], File['/usr/share/nginx/html']],")
    error_message = "The nginx service must require the website files as well as the package."
  }

  assert {
    condition     = strcontains(nonsensitive(aws_instance.puppet_master.user_data), "systemctl enable --now puppetserver")
    error_message = "The bootstrap script must start Puppet Server."
  }
}

# The DNS module needs this output to create the master's record.
run "output_exposes_private_ip" {
  command = apply

  assert {
    condition     = output.private_ip == aws_instance.puppet_master.private_ip
    error_message = "private_ip must be the instance's private IP."
  }
}
