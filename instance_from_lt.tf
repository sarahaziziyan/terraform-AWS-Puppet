resource "aws_instance" "from_template" {
  count = 4
  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }
  subnet_id = var.subnet_id
  tags = {
    Name = "online-course-${count.index + 1}"
  }
}