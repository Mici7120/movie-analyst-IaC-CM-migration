output "nlb_dns_name" {
  description = "Internal DNS name of the backend Network Load Balancer"
  value       = aws_lb.nlb.dns_name
}

output "rds_endpoint" {
  description = "RDS MySQL endpoint (host:port)"
  value       = aws_db_instance.mysql_db.endpoint
}

output "rds_address" {
  description = "RDS MySQL hostname (without port)"
  value       = aws_db_instance.mysql_db.address
}

output "rds_db_name" {
  description = "RDS MySQL database name"
  value       = aws_db_instance.mysql_db.db_name
}

output "ec2_security_group_id" {
  description = "Security group ID attached to backend EC2 instances"
  value       = aws_security_group.sg_ec2.id
}

output "asg_name" {
  description = "Name of the backend Auto Scaling Group"
  value       = aws_autoscaling_group.autoscaling.name
}
