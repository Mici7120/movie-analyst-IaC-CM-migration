variable "environment" {
  description = "Environment name"
  type        = string
  default     = "qa"
}

variable "vpc_name" {
  description = "VPC name"
  type        = string
  default     = "movie-analyst-vpc"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "vpc_azs" {
  description = "List of availability zones"
  type        = list(string)
}

variable "vpc_public_subnets" {
  description = "List of public subnet CIDR blocks"
  type        = list(string)
}

variable "vpc_private_subnets" {
  description = "List of private subnet CIDR blocks"
  type        = list(string)
}