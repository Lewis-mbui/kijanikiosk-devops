locals {
  servers = {
    api = {
      instance_type = var.instance_type
    }

    payments = {
      instance_type = var.instance_type
    }

    logs = {
      instance_type = var.instance_type
    }
  }
}

module "app_servers" {
  source   = "./modules/app_server"
  for_each = local.servers

  name          = "kijanikiosk-${each.key}-${var.environment}" # e.g kijanikiosk-api-staging
  service       = each.key
  instance_type = each.value.instance_type
  environment   = var.environment

  ami_id    = data.aws_ami.ubuntu.id
  subnet_id = data.aws_subnets.available.ids[0]

  key_name         = var.key_name
  vpc_id           = var.vpc_id
  allowed_ssh_cidr = var.my_ip
}
