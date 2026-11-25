variable "environment" {
  description = "Deployment environment name (e.g., dev, qa, prod)"
  type        = string
  default     = "qa"
}

variable "aws_region" {
  description = "AWS Region where resources will be provisioned"
  type        = string
  default     = "us-east-1"
}

variable "public_key_path" {
  description = "Path to the SSH public key file used for EC2 key pair"
  type        = string
  default     = "./ssh-keys/key-pair.pub"
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH into the Ansible Control Node (restrict to your IP in production)"
  type        = string
  default     = "0.0.0.0/0"
}

# --- VPC VARIABLES ---
variable "vpc_name" {
  description = "VPC name"
  type        = string
  default     = "movie-analyst-vpc"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_azs" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "vpc_public_subnets" {
  description = "List of public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "vpc_private_subnets" {
  description = "List of private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

# --- FRONTEND VARIABLES ---
variable "frontend_ami" {
  description = "AMI ID for the frontend EC2 instances"
  type        = string
}

variable "frontend_instance_type" {
  description = "EC2 instance type for frontend instances"
  type        = string
  default     = "t3.micro"
}

variable "frontend_autoscaling_max_size" {
  description = "Maximum size of the frontend Auto Scaling Group"
  type        = number
  default     = 4
}

variable "frontend_autoscaling_min_size" {
  description = "Minimum size of the frontend Auto Scaling Group"
  type        = number
  default     = 2
}

variable "frontend_autoscaling_desired_capacity" {
  description = "Desired capacity of the frontend Auto Scaling Group"
  type        = number
  default     = 2
}

# --- BACKEND & RDS VARIABLES ---
variable "backend_ami" {
  description = "AMI ID for the backend EC2 instances"
  type        = string
}

variable "backend_instance_type" {
  description = "EC2 instance type for backend instances"
  type        = string
  default     = "t3.micro"
}

variable "backend_app_port" {
  description = "Port on which the backend API listens and the internal NLB forwards traffic"
  type        = number
  default     = 3000
}

variable "backend_autoscaling_max_size" {
  description = "Maximum size of the backend Auto Scaling Group"
  type        = number
  default     = 4
}

variable "backend_autoscaling_min_size" {
  description = "Minimum size of the backend Auto Scaling Group"
  type        = number
  default     = 2
}

variable "backend_autoscaling_desired_capacity" {
  description = "Desired capacity of the backend Auto Scaling Group"
  type        = number
  default     = 2
}

variable "mysql_username" {
  description = "Master username for RDS MySQL"
  type        = string
  default     = "admin"
  sensitive   = true
}

variable "mysql_password" {
  description = "Master password for RDS MySQL"
  type        = string
  sensitive   = true
}

variable "rds_db_name" {
  description = "Initial database name created in RDS MySQL"
  type        = string
  default     = "movie_db"
}

variable "rds_instance_class" {
  description = "RDS MySQL instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_multi_az" {
  description = "Enable Multi-AZ deployment for RDS MySQL (us-east-1a/b)"
  type        = bool
  default     = true
}

# --- ANSIBLE CONTROL NODE VARIABLES ---
variable "ansible_instance_type" {
  description = "EC2 instance type for the Ansible Control Node"
  type        = string
  default     = "t3.micro"
}

variable "ansible_ami" {
  description = "AMI ID for the Ansible Control Node"
  type        = string
}