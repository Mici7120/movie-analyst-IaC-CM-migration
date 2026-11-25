module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.16"

  name = var.vpc_name
  cidr = var.vpc_cidr

  azs             = var.vpc_azs
  public_subnets  = var.vpc_public_subnets
  private_subnets = var.vpc_private_subnets

  # Allocate a single NAT Gateway in the first public subnet for private subnet egress
  enable_nat_gateway = true
  single_nat_gateway = true

  # Enable DNS resolution and public IPs on public subnets (required for RDS and public EC2 egress)
  enable_dns_hostnames    = true
  enable_dns_support      = true
  map_public_ip_on_launch = true

  tags = {
    terraform   = "true"
    environment = var.environment
  }
}