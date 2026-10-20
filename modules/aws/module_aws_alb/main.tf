# Application Load Balancer
resource "aws_lb" "web" {
  name_prefix     = "alb-"
  subnets         = var.subnet_ids
  security_groups = var.security_group_ids

  tags = {
    Name = "web-alb"
  }
}

# Target Group for health checks
resource "aws_lb_target_group" "web" {
  name_prefix = "tg-"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
  }

  tags = {
    Name = "web-tg"
  }
}

# ALB Listener - HTTP on port 80
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}
