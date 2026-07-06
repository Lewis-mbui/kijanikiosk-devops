output "public_ips" {
  description = "Public IP addresses of all application servers."

  value = {
    for name, server in module.app_servers :
    name => server.public_ip
  }
}

output "ssh_commands" {
  description = "SSH commands for all application servers."

  value = {
    for name, server in module.app_servers :
    name => "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${server.public_ip}"
  }
}
