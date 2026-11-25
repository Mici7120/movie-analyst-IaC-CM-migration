variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "vpc_private_subnets" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "List of public subnet CIDR blocks (frontend tier)"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "List of private subnet CIDR blocks (backend tier)"
  type        = list(string)
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "qa"
}

variable "backend_ami" {
  description = "AMI ID for backend EC2 instances"
  type        = string
}

variable "backend_instance_type" {
  description = "EC2 instance type for backend instances"
  type        = string
}

variable "backend_app_port" {
  description = "Port on which the backend API listens"
  type        = number
  default     = 3000
}

variable "backend_autoscaling_max_size" {
  description = "Maximum size of the backend Auto Scaling Group"
  type        = number
}

variable "backend_autoscaling_min_size" {
  description = "Minimum size of the backend Auto Scaling Group"
  type        = number
}

variable "backend_autoscaling_desired_capacity" {
  description = "Desired capacity of the backend Auto Scaling Group"
  type        = number
}

variable "key_pair_name" {
  description = "EC2 SSH key pair name"
  type        = string
}

variable "control_node_sg_id" {
  description = "Security group ID of the Ansible Control Node for SSH access"
  type        = string
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
  description = "Enable Multi-AZ deployment for RDS MySQL"
  type        = bool
  default     = true
}