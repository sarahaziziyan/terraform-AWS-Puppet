# Look up the latest Amazon Linux 2023 AMI
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_launch_template" "web" {
  name_prefix   = "lt-"
  image_id      = data.aws_ssm_parameter.al2023.value
  instance_type = "t3.micro"
  key_name      = var.key_name

  monitoring {
    enabled = true
  }

  # IMDSv2 only: blocks SSRF-style reads of user data (which holds the autosign secret).
  # The bootstrap script already requests a token before reading metadata.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  vpc_security_group_ids = var.security_group_ids

  # Encrypt the root volume explicitly instead of relying on the account's EBS default.
  # /dev/xvda is the root device name of the Amazon Linux 2023 AMI.
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      encrypted = true
    }
  }

  user_data = base64encode(templatefile("${path.module}/user_data_nodes.tftpl", {
    site_repo_url          = var.site_repo_url
    site_repo_branch       = var.site_repo_branch
    puppet_master_fqdn     = var.puppet_master_fqdn
    puppet_autosign_secret = var.puppet_autosign_secret
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name       = "online-course"
      Created_By = "Terraform"
    }
  }

  update_default_version = true
}
