variable "environment" {
  description = "Environment name"
  type        = string
  default     = "qa"
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet ID for the Ansible Control Node (us-east-1b)"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the Control Node"
  type        = string
}

variable "ami" {
  description = "AMI ID for the Control Node"
  type        = string
}

variable "key_pair_name" {
  description = "EC2 SSH key pair name"
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH into the Control Node"
  type        = string
  default     = "0.0.0.0/0"
}