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
# The security group lets in every CloudFront distribution, including other AWS customers'.
# Only requests carrying this stack's secret origin header (added by its own distribution)
# reach the web nodes; everything else gets 403.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Forbidden"
      status_code  = "403"
    }
  }
}

resource "aws_lb_listener_rule" "from_cloudfront" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 1

  condition {
    http_header {
      http_header_name = var.origin_header_name
      values           = [var.origin_header_value]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}
