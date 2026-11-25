variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "vpc_public_subnets" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "qa"
}

variable "frontend_ami" {
  description = "AMI ID for frontend EC2 instances"
  type        = string
}

variable "frontend_instance_type" {
  description = "EC2 instance type for frontend instances"
  type        = string
}

variable "frontend_autoscaling_max_size" {
  description = "Maximum size of the frontend Auto Scaling Group"
  type        = number
}

variable "frontend_autoscaling_min_size" {
  description = "Minimum size of the frontend Auto Scaling Group"
  type        = number
}

variable "frontend_autoscaling_desired_capacity" {
  description = "Desired capacity of the frontend Auto Scaling Group"
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
