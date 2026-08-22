variable "name" {
  description = "Name assigned to the EC2 instance."
  type        = string
}

variable "service" {
  description = "Logical service name used for tagging."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.micro"
}

variable "environment" {
  description = "Deployment environment."
  type        = string
}

variable "ami_id" {
  description = "AMI ID used to launch the EC2 instance."
  type        = string
}

variable "key_name" {
  description = "SSH key pair name."
  type        = string
}

variable "subnet_id" {
  description = "Subnet where the EC2 instance will be launched."
  type        = string
}

variable "vpc_id" {
  description = "VPC where the security group will be created."
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH into the instance."
  type        = string
}
