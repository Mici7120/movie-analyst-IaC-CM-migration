output "vpc_id" {
  description = "ID of the provisioned VPC"
  value       = module.vpc.vpc_id
}

output "alb_dns_name" {
  description = "Public DNS name of the Frontend Application Load Balancer"
  value       = module.frontend.alb_dns_name
}

output "nlb_dns_name" {
  description = "Internal DNS name of the Backend Network Load Balancer"
  value       = module.backend.nlb_dns_name
}

output "rds_endpoint" {
  description = "RDS MySQL endpoint (host:port)"
  value       = module.backend.rds_endpoint
}

output "rds_address" {
  description = "RDS MySQL hostname (without port)"
  value       = module.backend.rds_address
}

output "rds_db_name" {
  description = "RDS MySQL database name"
  value       = module.backend.rds_db_name
}

output "control_node_public_ip" {
  description = "Public IP address of the Ansible Control Node"
  value       = module.ansible_management.ip_node
}
