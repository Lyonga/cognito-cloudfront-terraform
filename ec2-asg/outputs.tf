output "document_name" {
  value = aws_ssm_document.install_agents.name
}

# output "eventbridge_rule" {
#   value = aws_eventbridge_rule.immediate_agent_install.name
# }


# output "autoscaling_group_name" {
#   description = "AutoScaling Group name"
#   value       = aws_autoscaling_group.ec2_asg.name

# }

# output "load_balancer_dns" {
#   description = "DNS name of the Load Balancer"
#   value       = aws_lb.alb.dns_name

# }

# output "launch_template_id" {
#   description = "The ID of the Launch Template"
#   value       = aws_launch_template.asg_instance_launch_template.id
# }

# output "file_system_id" {
#   description = "The ID of the EFS FileSystem"
#   value       = aws_efs_file_system.ds_efs_file_system.id
# }

output "instance_id" {
  description = "EC2 Instance ID"
  value       = aws_instance.generic.id
}
