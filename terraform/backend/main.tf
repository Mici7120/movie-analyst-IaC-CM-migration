# --- RDS MySQL ---
resource "aws_db_subnet_group" "db_subnet_group" {
  name_prefix = "${var.environment}-mysql-subnets-"
  subnet_ids  = var.vpc_private_subnets

  tags = {
    Name        = "${var.environment}-mysql-subnet-group"
    environment = var.environment
  }
}

resource "aws_security_group" "sg_rds" {
  name_prefix = "${var.environment}-rds-mysql-"
  description = "Security group for the RDS MySQL database"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "${var.environment}-rds-mysql-sg"
    environment = var.environment
    terraform   = "true"
  }
}

# Allow MySQL (3306) strictly from backend EC2 instances
resource "aws_vpc_security_group_ingress_rule" "rds_ingress_mysql_from_backend" {
  security_group_id            = aws_security_group.sg_rds.id
  referenced_security_group_id = aws_security_group.sg_ec2.id
  from_port                    = 3306
  ip_protocol                  = "tcp"
  to_port                      = 3306
}

resource "aws_vpc_security_group_egress_rule" "rds_egress_traffic_ipv4" {
  security_group_id = aws_security_group.sg_rds.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_db_instance" "mysql_db" {
  identifier_prefix      = "${var.environment}-movie-analyst-"
  allocated_storage      = 20
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = var.rds_instance_class
  db_name                = var.rds_db_name
  username               = var.mysql_username
  password               = var.mysql_password
  parameter_group_name   = "default.mysql8.0"
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  multi_az               = var.rds_multi_az
  publicly_accessible    = false
  vpc_security_group_ids = [aws_security_group.sg_rds.id]
  skip_final_snapshot    = true
  storage_encrypted      = true

  tags = {
    Name        = "${var.environment}-movie-analyst-mysql"
    environment = var.environment
    terraform   = "true"
  }
}

# --- Internal NLB Security Group ---
resource "aws_security_group" "sg_nlb" {
  name_prefix = "${var.environment}-backend-nlb-"
  description = "Security group for the internal backend Network Load Balancer"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "${var.environment}-backend-nlb-sg"
    environment = var.environment
    terraform   = "true"
  }
}

resource "aws_vpc_security_group_ingress_rule" "nlb_ingress_from_public_subnets" {
  for_each = toset(var.public_subnet_cidrs)

  security_group_id = aws_security_group.sg_nlb.id
  cidr_ipv4         = each.value
  from_port         = var.backend_app_port
  ip_protocol       = "tcp"
  to_port           = var.backend_app_port
}

resource "aws_vpc_security_group_egress_rule" "nlb_egress_to_private_subnets" {
  for_each = toset(var.private_subnet_cidrs)

  security_group_id = aws_security_group.sg_nlb.id
  cidr_ipv4         = each.value
  from_port         = var.backend_app_port
  ip_protocol       = "tcp"
  to_port           = var.backend_app_port
}

# --- Internal Network Load Balancer ---
resource "aws_lb" "nlb" {
  name_prefix        = "be-"
  internal           = true
  load_balancer_type = "network"
  security_groups    = [aws_security_group.sg_nlb.id]
  subnets            = var.vpc_private_subnets

  tags = {
    Name        = "${var.environment}-backend-nlb"
    environment = var.environment
    terraform   = "true"
  }
}

resource "aws_lb_target_group" "target" {
  name_prefix = "be-"
  port        = var.backend_app_port
  protocol    = "TCP"
  vpc_id      = var.vpc_id

  health_check {
    protocol            = "TCP"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name        = "${var.environment}-backend-tg"
    environment = var.environment
  }
}

resource "aws_lb_listener" "tcp" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = var.backend_app_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target.arn
  }
}

# --- Backend EC2 Security Group ---
resource "aws_security_group" "sg_ec2" {
  name_prefix = "${var.environment}-backend-ec2-"
  description = "Security group for backend EC2 instances"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "${var.environment}-backend-ec2-sg"
    environment = var.environment
    terraform   = "true"
  }
}

# NLB preserves client IP for instance targets; allow backend port from frontend (public) & NLB health checks (private) subnets
resource "aws_vpc_security_group_ingress_rule" "allow_app_port_from_vpc_subnets" {
  for_each = toset(concat(var.public_subnet_cidrs, var.private_subnet_cidrs))

  security_group_id = aws_security_group.sg_ec2.id
  cidr_ipv4         = each.value
  from_port         = var.backend_app_port
  ip_protocol       = "tcp"
  to_port           = var.backend_app_port
}

# Allow SSH strictly from the Ansible Control Node security group
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
  name_prefix   = "${var.environment}-backend-lt-"
  image_id      = var.backend_ami
  instance_type = var.backend_instance_type
  key_name      = var.key_pair_name

  network_interfaces {
    security_groups = [aws_security_group.sg_ec2.id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.environment}-backend"
      Role        = "backend"
      environment = var.environment
    }
  }
}

# --- Auto Scaling Group ---
resource "aws_autoscaling_group" "autoscaling" {
  name_prefix         = "${var.environment}-backend-asg-"
  max_size            = var.backend_autoscaling_max_size
  min_size            = var.backend_autoscaling_min_size
  desired_capacity    = var.backend_autoscaling_desired_capacity
  vpc_zone_identifier = var.vpc_private_subnets

  health_check_grace_period = 300
  health_check_type         = "ELB"

  launch_template {
    id      = aws_launch_template.ec2_template.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.target.arn]

  tag {
    key                 = "Name"
    value               = "${var.environment}-backend"
    propagate_at_launch = true
  }

  tag {
    key                 = "Role"
    value               = "backend"
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
  name                   = "${var.environment}-backend-cpu-target-tracking"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.autoscaling.name

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }
}