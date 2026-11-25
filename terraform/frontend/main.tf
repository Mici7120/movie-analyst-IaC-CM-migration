# --- ALB Security Group ---
resource "aws_security_group" "sg_alb" {
  name_prefix = "${var.environment}-frontend-alb-"
  description = "Security group for the frontend Application Load Balancer"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "${var.environment}-frontend-alb-sg"
    environment = var.environment
    terraform   = "true"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ingress_http_ipv4" {
  security_group_id = aws_security_group.sg_alb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "egress_traffic_ipv4" {
  security_group_id = aws_security_group.sg_alb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# --- Application Load Balancer ---
resource "aws_lb" "alb" {
  name_prefix        = "fe-"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sg_alb.id]
  subnets            = var.vpc_public_subnets

  tags = {
    Name        = "${var.environment}-frontend-alb"
    environment = var.environment
    terraform   = "true"
  }
}

resource "aws_lb_target_group" "target" {
  name_prefix = "fe-"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name        = "${var.environment}-frontend-tg"
    environment = var.environment
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target.arn
  }
}

# --- Frontend EC2 Security Group ---
resource "aws_security_group" "sg_ec2" {
  name_prefix = "${var.environment}-frontend-ec2-"
  description = "Security group for frontend EC2 instances"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "${var.environment}-frontend-ec2-sg"
    environment = var.environment
    terraform   = "true"
  }
}

# Allow HTTP only from the ALB (prevents direct internet bypass)
resource "aws_vpc_security_group_ingress_rule" "allow_http_from_alb" {
  security_group_id            = aws_security_group.sg_ec2.id
  referenced_security_group_id = aws_security_group.sg_alb.id
  from_port                    = 80
  ip_protocol                  = "tcp"
  to_port                      = 80
}

# Allow SSH only from the Ansible Control Node security group
resource "aws_vpc_security_group_ingress_rule" "allow_ssh_from_control_node" {
  security_group_id            = aws_security_group.sg_ec2.id
  referenced_security_group_id = var.control_node_sg_id
  from_port                    = 22
  ip_protocol                  = "tcp"
  to_port                      = 22
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.sg_ec2.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# --- Launch Template ---
resource "aws_launch_template" "ec2_template" {
  name_prefix   = "${var.environment}-frontend-lt-"
  image_id      = var.frontend_ami
  instance_type = var.frontend_instance_type
  key_name      = var.key_pair_name

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.sg_ec2.id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.environment}-frontend"
      Role        = "frontend"
      environment = var.environment
    }
  }
}

# --- Auto Scaling Group ---
resource "aws_autoscaling_group" "autoscaling" {
  name_prefix         = "${var.environment}-frontend-asg-"
  max_size            = var.frontend_autoscaling_max_size
  min_size            = var.frontend_autoscaling_min_size
  desired_capacity    = var.frontend_autoscaling_desired_capacity
  vpc_zone_identifier = var.vpc_public_subnets

  health_check_grace_period = 300
  health_check_type         = "ELB"

  launch_template {
    id      = aws_launch_template.ec2_template.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.target.arn]

  tag {
    key                 = "Name"
    value               = "${var.environment}-frontend"
    propagate_at_launch = true
  }

  tag {
    key                 = "Role"
    value               = "frontend"
    propagate_at_launch = true
  }

  tag {
    key                 = "environment"
    value               = var.environment
    propagate_at_launch = true
  }
}

# Single TargetTrackingScaling policy handles both scale-out and scale-in automatically
resource "aws_autoscaling_policy" "cpu_target_tracking" {
  name                   = "${var.environment}-frontend-cpu-target-tracking"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.autoscaling.name

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }
}