output "instance_id" {
  description = "ID of the KijaniKiosk API EC2 instance."
  value       = aws_instance.kk_api.id
}

output "api_server_public_ip" {
  description = "Public IP address of the KijaniKiosk API server."
  value       = aws_instance.kk_api.public_ip
}

output "api_server_private_ip" {
  description = "Private IP address of the KijaniKiosk API server."
  value       = aws_instance.kk_api.private_ip
}

output "api_server_public_dns" {
  description = "Public DNS of the KijaniKiosk API server"
  value       = aws_instance.kk_api.public_dns
}

output "ssh_command" {
  description = "SSH command to connect to the API server"
  value       = "ssh -i ~/.ssh/kijanikiosk-key-aws.pem ubuntu@${aws_instance.kk_api.public_ip}"
  sensitive   = false # Set to true for outputs that contain secrets
}
