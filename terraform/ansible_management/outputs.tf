output "ip_node" {
  description = "Public IP address of the Ansible Control Node"
  value       = aws_instance.control_node.public_ip
}

output "instance_id" {
  description = "Instance ID of the Ansible Control Node"
  value       = aws_instance.control_node.id
}

output "security_group_id" {
  description = "Security group ID of the Ansible Control Node"
  value       = aws_security_group.sg_control.id
}