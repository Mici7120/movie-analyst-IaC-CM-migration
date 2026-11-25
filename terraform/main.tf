terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "terraform"
      Project     = "movie-analyst"
    }
  }
}

resource "aws_key_pair" "key" {
  key_name   = "${var.environment}-movie-analyst-key"
  public_key = file(var.public_key_path)

  tags = {
    Name = "${var.environment}-movie-analyst-key"
  }
}

module "vpc" {
  source = "./vpc"

  environment         = var.environment
  vpc_name            = var.vpc_name
  vpc_cidr            = var.vpc_cidr
  vpc_azs             = var.vpc_azs
  vpc_public_subnets  = var.vpc_public_subnets
  vpc_private_subnets = var.vpc_private_subnets
}

module "ansible_management" {
  source = "./ansible_management"

  environment      = var.environment
  vpc_id           = module.vpc.vpc_id
  public_subnet_id = module.vpc.public_subnets[1]
  instance_type    = var.ansible_instance_type
  ami              = var.ansible_ami
  key_pair_name    = aws_key_pair.key.key_name
  allowed_ssh_cidr = var.allowed_ssh_cidr
}

module "frontend" {
  source = "./frontend"

  environment                           = var.environment
  vpc_id                                = module.vpc.vpc_id
  vpc_public_subnets                    = module.vpc.public_subnets
  frontend_ami                          = var.frontend_ami
  frontend_instance_type                = var.frontend_instance_type
  frontend_autoscaling_max_size         = var.frontend_autoscaling_max_size
  frontend_autoscaling_min_size         = var.frontend_autoscaling_min_size
  frontend_autoscaling_desired_capacity = var.frontend_autoscaling_desired_capacity
  key_pair_name                         = aws_key_pair.key.key_name
  control_node_sg_id                    = module.ansible_management.security_group_id
}

module "backend" {
  source = "./backend"

  environment                          = var.environment
  vpc_id                               = module.vpc.vpc_id
  vpc_private_subnets                  = module.vpc.private_subnets
  public_subnet_cidrs                  = var.vpc_public_subnets
  private_subnet_cidrs                 = var.vpc_private_subnets
  backend_ami                          = var.backend_ami
  backend_instance_type                = var.backend_instance_type
  backend_app_port                     = var.backend_app_port
  backend_autoscaling_max_size         = var.backend_autoscaling_max_size
  backend_autoscaling_min_size         = var.backend_autoscaling_min_size
  backend_autoscaling_desired_capacity = var.backend_autoscaling_desired_capacity
  key_pair_name                        = aws_key_pair.key.key_name
  control_node_sg_id                   = module.ansible_management.security_group_id
  mysql_username                       = var.mysql_username
  mysql_password                       = var.mysql_password
  rds_db_name                          = var.rds_db_name
  rds_instance_class                   = var.rds_instance_class
  rds_multi_az                         = var.rds_multi_az
}