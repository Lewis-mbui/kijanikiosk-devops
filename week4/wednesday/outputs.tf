output "instance_ids" {
  description = "Instance IDs of all application servers."

  value = {
    for name, server in module.app_servers :
    name => server.instance_id
  }
}

output "public_ips" {
  description = "Public IP addresses of all application servers."

  value = {
    for name, server in module.app_servers :
    name => server.public_ip
  }
}

output "private_ips" {
  description = "Private IP addresses of all application servers."

  value = {
    for name, server in module.app_servers :
    name => server.private_ip
  }
}
