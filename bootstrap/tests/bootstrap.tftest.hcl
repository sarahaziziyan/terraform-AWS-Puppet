# Unit tests for the admin-applied bootstrap config.
# The AWS provider is mocked; the random provider runs locally. No credentials are needed.
# Run from the bootstrap folder:  terraform init -backend=false && terraform test

mock_provider "aws" {
  mock_resource "aws_ssm_parameter" {
    defaults = {
      arn = "arn:aws:ssm:ap-southeast-1:123456789012:parameter/puppet/autosign-secret"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/mock-role"
    }
  }
}

# Known issue 5: the secret is an encrypted parameter, set write-only so it never reaches the state.
run "secret_is_encrypted_and_write_only" {
  command = apply

  assert {
    condition     = aws_ssm_parameter.autosign_secret.type == "SecureString"
    error_message = "The autosign secret must be a SecureString (encrypted with KMS)."
  }

  # value_wo itself cannot be read back (that is the point of write-only), and the mock fills in
  # the computed `value`, so the test checks the version that drives writes and rotation.
  assert {
    condition     = aws_ssm_parameter.autosign_secret.value_wo_version == var.autosign_secret_version
    error_message = "The secret must be written through value_wo, driven by autosign_secret_version."
  }

  assert {
    condition     = output.autosign_secret_parameter_name == "/puppet/autosign-secret"
    error_message = "The parameter name must match the main stack's default."
  }
}

# Each instance role may read that one parameter and nothing else.
run "instance_roles_can_only_read_the_secret" {
  command = apply

  assert {
    condition = alltrue([
      for p in aws_iam_role_policy.read_autosign_secret :
      jsondecode(p.policy).Statement[0].Action == "ssm:GetParameter" &&
      jsondecode(p.policy).Statement[0].Resource == aws_ssm_parameter.autosign_secret.arn &&
      length(jsondecode(p.policy).Statement) == 1
    ])
    error_message = "Each role's only permission must be ssm:GetParameter on the autosign secret parameter."
  }

  assert {
    condition = alltrue([
      for r in aws_iam_role.instance :
      jsondecode(r.assume_role_policy).Statement[0].Principal.Service == "ec2.amazonaws.com"
    ])
    error_message = "Only EC2 may assume the instance roles."
  }

  assert {
    condition = (
      output.puppet_master_instance_profile_name == "puppet-master-autosign-reader" &&
      output.web_node_instance_profile_name == "web-node-autosign-reader"
    )
    error_message = "The instance profile names must match the main stack's defaults."
  }
}

# terraform-user may only pass these two roles, and only to EC2.
run "terraform_user_can_only_pass_these_roles" {
  command = apply

  assert {
    condition     = aws_iam_user_policy.terraform_user_pass_roles.user == "terraform-user"
    error_message = "The PassRole policy must be attached to terraform-user."
  }

  assert {
    condition = (
      jsondecode(aws_iam_user_policy.terraform_user_pass_roles.policy).Statement[0].Action == "iam:PassRole" &&
      length(jsondecode(aws_iam_user_policy.terraform_user_pass_roles.policy).Statement) == 1
    )
    error_message = "terraform-user must get iam:PassRole only."
  }

  assert {
    condition     = toset(jsondecode(aws_iam_user_policy.terraform_user_pass_roles.policy).Statement[0].Resource) == toset([for r in aws_iam_role.instance : r.arn])
    error_message = "PassRole must be limited to the two instance roles."
  }

  assert {
    condition     = jsondecode(aws_iam_user_policy.terraform_user_pass_roles.policy).Statement[0].Condition.StringEquals["iam:PassedToService"] == "ec2.amazonaws.com"
    error_message = "The roles may only be passed to EC2."
  }
}
