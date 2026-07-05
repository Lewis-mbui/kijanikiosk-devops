# # security group
# resource "aws_security_group" "kk_api_sg" {
#   name        = "kijanikiosk-api-sg"
#   description = "Security group for the KijaniKiosk API server"
#   vpc_id      = var.vpc_id

#   ingress {
#     description = "SSH from current client IP"
#     from_port   = 22
#     to_port     = 22
#     protocol    = "tcp"
#     cidr_blocks = [var.my_ip]
#   }

#   ingress {
#     description = "HTTP"
#     from_port   = 80
#     to_port     = 80
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   egress {
#     description = "Allow all outbound traffic"
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Name        = "kijanikiosk-api-sg"
#     Environment = var.environment
#     Owner       = var.owner
#   }
# }

# resource "aws_instance" "kk_api" {
#   ami                    = data.aws_ami.ubuntu.id
#   instance_type          = var.instance_type
#   availability_zone      = var.availabiliity_zone
#   subnet_id              = data.aws_subnets.available.ids[0]
#   key_name               = var.key_name
#   vpc_security_group_ids = [aws_security_group.kk_api_sg.id]

#   root_block_device {
#     volume_size = 8
#     volume_type = "gp3"
#   }

#   tags = {
#     Name        = var.instance_name
#     Environment = var.environment
#     Owner       = var.owner
#   }
# }
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
