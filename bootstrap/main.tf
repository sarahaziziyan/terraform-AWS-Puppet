# Admin-only resources for the Puppet autosign secret (known issue 5).
# Apply this folder with administrator credentials. The main stack only refers to the two
# instance profiles by name, so terraform-user never creates IAM roles or sees the secret.

# Generated on every run but never stored: ephemeral values do not reach the plan or the state.
# Letters and digits only, so it is safe in shell scripts and YAML.
ephemeral "random_password" "autosign" {
  length  = 48
  special = false
}

# Encrypted with the AWS-managed aws/ssm key. value_wo is write-only: Terraform sends it to AWS
# and keeps nothing. A new secret is written only when autosign_secret_version changes.
resource "aws_ssm_parameter" "autosign_secret" {
  name             = var.autosign_secret_parameter_name
  description      = "Puppet autosign shared secret. Read at boot by the Puppet master and the web nodes"
  type             = "SecureString"
  value_wo         = ephemeral.random_password.autosign.result
  value_wo_version = var.autosign_secret_version
}

locals {
  ec2_assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  # The only permission either instance gets. The aws/ssm key's own policy lets SSM decrypt
  # for callers in this account, so no KMS permission is needed.
  read_autosign_secret_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "ReadAutosignSecret"
      Effect   = "Allow"
      Action   = "ssm:GetParameter"
      Resource = aws_ssm_parameter.autosign_secret.arn
    }]
  })

  instance_roles = {
    puppet_master = var.puppet_master_role_name
    web_node      = var.web_node_role_name
  }
}

resource "aws_iam_role" "instance" {
  for_each = local.instance_roles

  name               = each.value
  description        = "Lets the instance read the Puppet autosign secret, nothing else"
  assume_role_policy = local.ec2_assume_role_policy
}

resource "aws_iam_role_policy" "read_autosign_secret" {
  for_each = local.instance_roles

  name   = "read-autosign-secret"
  role   = aws_iam_role.instance[each.key].id
  policy = local.read_autosign_secret_policy
}

resource "aws_iam_instance_profile" "instance" {
  for_each = local.instance_roles

  name = each.value
  role = aws_iam_role.instance[each.key].name
}

# terraform-user may attach these two roles to EC2 instances (iam:PassRole), and nothing else:
# it cannot create roles, change their permissions, or pass any other role.
resource "aws_iam_user_policy" "terraform_user_pass_roles" {
  name = "pass-autosign-reader-roles"
  user = var.terraform_user_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "PassAutosignReaderRolesToEc2"
      Effect   = "Allow"
      Action   = "iam:PassRole"
      Resource = [for r in aws_iam_role.instance : r.arn]
      Condition = {
        StringEquals = { "iam:PassedToService" = "ec2.amazonaws.com" }
      }
    }]
  })
}
