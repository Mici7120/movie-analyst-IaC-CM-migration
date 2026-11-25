output "alb_dns_name" {
  description = "Public DNS name of the frontend Application Load Balancer"
  value       = aws_lb.alb.dns_name
}

output "alb_arn" {
  description = "ARN of the frontend Application Load Balancer"
  value       = aws_lb.alb.arn
}

output "ec2_security_group_id" {
  description = "Security group ID attached to frontend EC2 instances"
  value       = aws_security_group.sg_ec2.id
}

output "asg_name" {
  description = "Name of the frontend Auto Scaling Group"
  value       = aws_autoscaling_group.autoscaling.name
}
