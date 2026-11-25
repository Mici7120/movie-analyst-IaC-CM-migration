# --- Security Group for Ansible Control Node ---
resource "aws_security_group" "sg_control" {
  name_prefix = "${var.environment}-ansible-control-"
  description = "Security group for the Ansible Control Node instance"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "${var.environment}-ansible-control-sg"
    environment = var.environment
    terraform   = "true"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh_ipv4" {
  security_group_id = aws_security_group.sg_control.id
  cidr_ipv4         = var.allowed_ssh_cidr
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.sg_control.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# --- IAM Role for Dynamic EC2 Inventory (no static AWS keys on the instance) ---
resource "aws_iam_role" "control_node_role" {
  name_prefix = "${var.environment}-ansible-control-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.environment}-ansible-control-role"
    environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "ec2_readonly" {
  role       = aws_iam_role.control_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

resource "aws_iam_instance_profile" "control_node_profile" {
  name_prefix = "${var.environment}-ansible-control-"
  role        = aws_iam_role.control_node_role.name
}

# --- Ansible Control Node EC2 Instance (public subnet us-east-1b) ---
resource "aws_instance" "control_node" {
  subnet_id                   = var.public_subnet_id
  instance_type               = var.instance_type
  ami                         = var.ami
  key_name                    = var.key_pair_name
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.sg_control.id]
  iam_instance_profile        = aws_iam_instance_profile.control_node_profile.name

  user_data = <<-EOF
    #!/bin/bash
    set -euo pipefail
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y ansible python3-boto3 python3-botocore git
    su - ubuntu -c "ansible-galaxy collection install amazon.aws community.mysql" || true
  EOF

  tags = {
    Name        = "${var.environment}-ansible-control-node"
    Role        = "control-node"
    terraform   = "true"
    environment = var.environment
  }
}