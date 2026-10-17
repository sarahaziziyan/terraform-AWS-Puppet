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

  vpc_security_group_ids = [aws_security_group.web.id]

  user_data = base64encode(templatefile("${path.module}/user_data.tpl", {}))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name       = "online-course"
      Created_By = "Terraform"
    }
  }

  update_default_version = true
}