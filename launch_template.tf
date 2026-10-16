# Look up the latest Amazon Linux 2023 AMI
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_launch_template" "web" {
  name_prefix   = "web-lt-"
  image_id      = data.aws_ssm_parameter.al2023.value
  instance_type = "t3.nano"
  key_name      = var.key_name

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "online-course"
    }
  }

  update_default_version = true
}